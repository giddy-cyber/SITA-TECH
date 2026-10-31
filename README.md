# SITA-TECH
ONLINE CYBER

## Supabase setup

The static site uses the publishable Supabase client in `supabaseClient.js`. This key is intended for browser use; never add a Supabase `service_role` key to frontend files.

1. In the Supabase SQL Editor for this project, run [`supabase/schema.sql`](./supabase/schema.sql).
2. Enable Supabase Auth and create/invite student accounts. New accounts receive a `student` profile automatically.
3. Assign staff access only from the trusted SQL Editor, for example:

   ```sql
   update public.sita_profiles
   set role = 'staff'
   where id = '<trusted staff auth user UUID>';
   ```

4. Staff can review enrollment applications and manage enrollments, payment records, class sessions, and certificates through the authenticated Supabase dashboard.

The migration uses `sita_`-prefixed table names so it does not conflict with existing project tables. Row Level Security is enabled for every application table. Enrollment submissions are insert-only for anonymous visitors; profile, payment, progress, class, and certificate records are not publicly readable. Students can read their own records and update only progress for active enrollments. Payment confirmation and certificate issuance must be performed by staff or a trusted server/Edge Function, never by browser code.

The student portal now requires Supabase Auth. Existing portal accounts and browser-stored progress are not migrated automatically; create/invite accounts and assign enrollments before switching students over. M-Pesa provider callbacks and certificate document generation are not implemented in this static frontend and require a trusted server-side function.
