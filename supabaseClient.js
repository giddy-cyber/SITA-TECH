import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = 'https://sklwiwhlzjwaydwhppnf.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_ZN8OmEX99eZtf_GeUs5dZg_PLVd1hUG';

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
    auth: {
        autoRefreshToken: true,
        detectSessionInUrl: true,
        persistSession: true
    }
});
