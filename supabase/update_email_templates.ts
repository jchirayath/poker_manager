#!/usr/bin/env node

/**
 * Script to update Supabase email templates from EMAIL_TEMPLATES.md
 *
 * Prerequisites:
 * - Add SUPABASE_ACCESS_TOKEN to env.json (get from: https://supabase.com/dashboard/account/tokens)
 *
 * Usage:
 *   npx tsx supabase/update_email_templates.ts
 */

import * as fs from 'fs';
import * as path from 'path';

interface EmailTemplate {
  name: string;
  type: string;
  subject: string;
  body: string;
}

interface EnvConfig {
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  SUPABASE_DB_URL: string;
  SUPABASE_ACCESS_TOKEN?: string;
}

const TEMPLATES_CONFIG = [
  { name: 'Confirm Signup', type: 'CONFIRMATION' },
  { name: 'Reset Password', type: 'RECOVERY' },
  { name: 'Magic Link', type: 'MAGIC_LINK' },
  { name: 'Invite User', type: 'INVITE' },
];

class EmailTemplateUpdater {
  private accessToken: string;
  private projectRef: string;
  private templatesFile: string;
  private envConfig: EnvConfig;

  constructor() {
    this.templatesFile = path.join(__dirname, 'EMAIL_TEMPLATES.md');
    this.envConfig = this.loadEnvConfig();
    this.projectRef = this.extractProjectRef(this.envConfig.SUPABASE_URL);
    this.accessToken = this.envConfig.SUPABASE_ACCESS_TOKEN || '';

    this.validateEnvironment();
  }

  private loadEnvConfig(): EnvConfig {
    const envPath = path.join(__dirname, '..', 'env.json');

    if (!fs.existsSync(envPath)) {
      console.error('\n❌ env.json file not found at:', envPath);
      console.error('   Make sure env.json exists in the project root\n');
      process.exit(1);
    }

    try {
      const envContent = fs.readFileSync(envPath, 'utf-8');
      return JSON.parse(envContent);
    } catch (error) {
      console.error('\n❌ Failed to parse env.json:', error instanceof Error ? error.message : String(error));
      process.exit(1);
    }
  }

  private extractProjectRef(supabaseUrl: string): string {
    // Extract project ref from URL like: https://evmicivjkcspqpnbjcus.supabase.co
    const match = supabaseUrl.match(/https:\/\/([^.]+)\.supabase\.co/);
    if (!match || !match[1]) {
      console.error('\n❌ Could not extract project reference from SUPABASE_URL:', supabaseUrl);
      console.error('   Expected format: https://YOUR_PROJECT_REF.supabase.co\n');
      process.exit(1);
    }
    return match[1];
  }

  private validateEnvironment(): void {
    const errors: string[] = [];

    if (!this.accessToken) {
      errors.push(
        '❌ SUPABASE_ACCESS_TOKEN is not set in env.json',
        '   Get your token from: https://supabase.com/dashboard/account/tokens',
        '   Add it to env.json as: "SUPABASE_ACCESS_TOKEN": "sbp_your_token_here"'
      );
    }

    if (!fs.existsSync(this.templatesFile)) {
      errors.push(`❌ Templates file not found: ${this.templatesFile}`);
    }

    if (errors.length > 0) {
      console.error('\n' + errors.join('\n') + '\n');
      process.exit(1);
    }

    console.log(`📋 Using project: ${this.projectRef}`);
    console.log(`📁 Reading templates from: ${path.basename(this.templatesFile)}\n`);
  }

  private extractTemplate(templateName: string, field: 'subject' | 'body'): string {
    const content = fs.readFileSync(this.templatesFile, 'utf-8');
    const lines = content.split('\n');

    // Find the section for this template
    const sectionStartRegex = new RegExp(`^## \\d+\\. ${templateName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`);
    const sectionStart = lines.findIndex(line => sectionStartRegex.test(line));

    if (sectionStart === -1) {
      throw new Error(`Template section not found: ${templateName}`);
    }

    // Find the next section or end of file
    const sectionEnd = lines.findIndex((line, idx) =>
      idx > sectionStart && /^## \d+\./.test(line)
    );
    const sectionLines = sectionEnd === -1
      ? lines.slice(sectionStart)
      : lines.slice(sectionStart, sectionEnd);

    if (field === 'subject') {
      // Extract subject (between **Subject:** and next ```)
      const subjectStart = sectionLines.findIndex(line => line.includes('**Subject:**'));
      if (subjectStart === -1) return '';

      const codeBlockStart = subjectStart + 1;
      const codeBlockEnd = sectionLines.findIndex((line, idx) =>
        idx > codeBlockStart && line.trim() === '```'
      );

      const subjectLines = sectionLines.slice(codeBlockStart + 1, codeBlockEnd);
      return subjectLines.join('\n').trim();
    } else {
      // Extract HTML body (between **Body (HTML):** and closing ```)
      const bodyStart = sectionLines.findIndex(line => line.includes('**Body (HTML):**'));
      if (bodyStart === -1) return '';

      const htmlStart = sectionLines.findIndex((line, idx) =>
        idx > bodyStart && line.trim() === '```html'
      );
      const htmlEnd = sectionLines.findIndex((line, idx) =>
        idx > htmlStart && line.trim() === '```'
      );

      if (htmlStart === -1 || htmlEnd === -1) return '';

      const bodyLines = sectionLines.slice(htmlStart + 1, htmlEnd);
      return bodyLines.join('\n');
    }
  }

  private async updateTemplate(template: EmailTemplate): Promise<void> {
    console.log(`📧 Updating ${template.name}...`);

    const url = `https://api.supabase.com/v1/projects/${this.projectRef}/config/auth`;

    const payload: Record<string, string> = {};
    payload[`mailer_subjects_${template.type.toLowerCase()}`] = template.subject;
    payload[`mailer_templates_${template.type.toLowerCase()}_content`] = template.body;

    try {
      const response = await fetch(url, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`HTTP ${response.status}: ${errorText}`);
      }

      console.log(`✅ Successfully updated ${template.name}\n`);
    } catch (error) {
      console.error(`❌ Failed to update ${template.name}`);
      console.error(`   Error: ${error instanceof Error ? error.message : String(error)}\n`);
      throw error;
    }
  }

  async run(): Promise<void> {
    console.log('\n🚀 Starting email template update...\n');

    const templates: EmailTemplate[] = [];

    // Extract all templates
    for (const config of TEMPLATES_CONFIG) {
      try {
        const subject = this.extractTemplate(config.name, 'subject');
        const body = this.extractTemplate(config.name, 'body');

        if (!subject || !body) {
          throw new Error(`Could not extract subject or body for ${config.name}`);
        }

        templates.push({
          name: config.name,
          type: config.type,
          subject,
          body,
        });
      } catch (error) {
        console.error(`❌ Error extracting ${config.name}:`);
        console.error(`   ${error instanceof Error ? error.message : String(error)}`);
        process.exit(1);
      }
    }

    console.log(`📄 Found ${templates.length} templates to update\n`);

    // Update all templates
    let successCount = 0;
    for (const template of templates) {
      try {
        await this.updateTemplate(template);
        successCount++;
      } catch (error) {
        console.error('Stopping due to error.\n');
        process.exit(1);
      }
    }

    console.log(`\n✨ Successfully updated ${successCount}/${templates.length} email templates!`);
    console.log('⏱️  Note: Changes may take a few minutes to propagate.\n');
  }
}

// Run the updater
const updater = new EmailTemplateUpdater();
updater.run().catch(error => {
  console.error('\n❌ Fatal error:', error);
  process.exit(1);
});
