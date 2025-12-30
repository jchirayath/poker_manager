-- Update existing profiles with 'US' to 'United States'
UPDATE public.profiles 
SET country = 'United States' 
WHERE country = 'US';

-- Also handle other common abbreviations
UPDATE public.profiles 
SET country = 'United States' 
WHERE country IN ('USA', 'U.S.', 'U.S.A.');

UPDATE public.profiles 
SET country = 'United Kingdom' 
WHERE country IN ('UK', 'GB');

UPDATE public.profiles 
SET country = 'Canada' 
WHERE country = 'CA';
