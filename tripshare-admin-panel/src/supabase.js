import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://jowldfpeltsserkqwpfs.supabase.co'; // from Settings → General
const supabaseKey = 'sb_publishable_uVoaP3F4cyXtjSfe_Fpeng_UX5i4_Ek'; // publishable key

export const supabase = createClient(supabaseUrl, supabaseKey);