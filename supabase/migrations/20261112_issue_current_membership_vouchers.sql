-- Issue the current periods immediately for databases where the membership
-- voucher scheduler was installed before immediate issuance was added.
-- Safe to rerun: the issuance function is idempotent for each user and period.
SELECT public.issue_membership_vouchers('weekly');
SELECT public.issue_membership_vouchers('monthly');
