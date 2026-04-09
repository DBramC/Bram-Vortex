-- =========================================================
-- 1. ΔΗΜΙΟΥΡΓΙΑ ΧΡΗΣΤΩΝ (Role-Based Access Control)
-- =========================================================
DO $$
    BEGIN
        -- Repo Analyzer (Ο "Δημιουργός" του Blueprint)
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'an_user') THEN
            CREATE USER an_user WITH PASSWORD 'an_vortex_2026';
        END IF;

        -- Terraform Generator (Infrastructure Creator)
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'tf_user') THEN
            CREATE USER tf_user WITH PASSWORD 'tf_vortex_2026';
        END IF;

        -- Ansible Generator (Configuration Creator)
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'as_user') THEN
            CREATE USER as_user WITH PASSWORD 'as_vortex_2026';
        END IF;

        -- Pipeline Service (Orchestrator - Read Only)
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'pp_user') THEN
            CREATE USER pp_user WITH PASSWORD 'pp_vortex_2026';
        END IF;

        -- Execution Service (Runner - Read Only)
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'ex_user') THEN
            CREATE USER ex_user WITH PASSWORD 'ex_vortex_2026';
        END IF;
    END $$;

-- Βασική σύνδεση στη βάση για όλους
GRANT CONNECT ON DATABASE vortexdb TO an_user, tf_user, as_user, pp_user, ex_user;
GRANT USAGE ON SCHEMA public TO an_user, tf_user, as_user, pp_user, ex_user;

-- =========================================================
-- 2. ΔΗΜΙΟΥΡΓΙΑ ΠΙΝΑΚΩΝ (Schema Definition)
-- =========================================================

-- Πίνακας: Analysis Jobs (Περιέχει το AI Blueprint)
CREATE TABLE IF NOT EXISTS analysis_jobs (
                                             job_id VARCHAR(255) PRIMARY KEY,
                                             blueprint_json JSONB,             -- Βελτιστοποιημένο JSON format
                                             created_at TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
                                             repo_id BIGINT,
                                             repo_name VARCHAR(255),
                                             status VARCHAR(255),
                                             target_cloud VARCHAR(255),
                                             user_id VARCHAR(255),
                                             prompt_message TEXT,
                                             compute_type VARCHAR(255),
                                             target_region VARCHAR(255),
                                             terraform_status VARCHAR(20) DEFAULT 'PENDING',
                                             ansible_status VARCHAR(20) DEFAULT 'PENDING',
                                             pipeline_status VARCHAR(20) DEFAULT 'PENDING'
);

-- Πίνακας: Terraform Jobs (Τα αποτελέσματα του TF Generator)
CREATE TABLE IF NOT EXISTS terraform_jobs (
                                              id VARCHAR(255) PRIMARY KEY,
                                              analysis_job_id VARCHAR(255) REFERENCES analysis_jobs(job_id),
                                              user_id VARCHAR(255),
                                              status VARCHAR(255),
                                              terraform_zip BYTEA                -- Binary storage για το ZIP
);

-- Πίνακας: Ansible Jobs (Τα αποτελέσματα του Ansible Generator)
CREATE TABLE IF NOT EXISTS ansible_jobs (
                                            id VARCHAR(255) PRIMARY KEY,
                                            analysis_job_id VARCHAR(255) REFERENCES analysis_jobs(job_id),
                                            user_id VARCHAR(255),
                                            status VARCHAR(255),
                                            ansible_zip BYTEA                 -- Binary storage για το ZIP
);

-- Πίνακας: Pipeline Jobs (Τα αποτελέσματα του Pipeline Generator)
CREATE TABLE IF NOT EXISTS pipeline_jobs (
                                             id VARCHAR(255) PRIMARY KEY,
                                             analysis_job_id VARCHAR(255) REFERENCES analysis_jobs(job_id),
                                             user_id VARCHAR(255),
                                             status VARCHAR(255),
                                             pipeline_zip BYTEA                 -- Binary storage για το ZIP
);

-- =========================================================
-- 3. ΑΠΟΔΟΣΗ ΔΙΚΑΙΩΜΑΤΩΝ (Isolation & Least Privilege)
-- =========================================================

-- --- REPO ANALYZER (an_user) ---
-- Πλήρη πρόσβαση στο Analysis, καμία στους Generators
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE analysis_jobs TO an_user;
GRANT SELECT ON TABLE terraform_jobs, ansible_jobs, pipeline_jobs TO an_user;

-- --- TERRAFORM GENERATOR (tf_user) ---
-- Ανάγνωση του Blueprint, εγγραφή ΜΟΝΟ στον δικό του πίνακα
GRANT SELECT ON TABLE analysis_jobs TO tf_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE terraform_jobs TO tf_user;

-- --- ANSIBLE GENERATOR (as_user) ---
-- Ανάγνωση του Blueprint, εγγραφή ΜΟΝΟ στον δικό του πίνακα
GRANT SELECT ON TABLE analysis_jobs TO as_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE ansible_jobs TO as_user;

-- --- PIPELINE GENERATOR (pp_user) ---
-- Ανάγνωση του Blueprint, εγγραφή ΜΟΝΟ στον δικό του πίνακα
GRANT SELECT ON TABLE analysis_jobs TO pp_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE pipeline_jobs TO pp_user;

-- --- EXECUTION SERVICE (ex_user) ---
-- Απόλυτο Read-Only σε όλα τα δεδομένα για συντονισμό και deployment
GRANT SELECT ON TABLE analysis_jobs TO ex_user;
GRANT SELECT ON TABLE analysis_jobs, terraform_jobs, ansible_jobs, pipeline_jobs TO ex_user;

-- Δικαιώματα σε Sequences (χρειάζεται για auto-increment IDs αν προστεθούν)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO an_user, tf_user, as_user;

-- =========================================================
-- 4. SECURITY CHECK
-- =========================================================
-- Αφαιρούμε τη δυνατότητα στον "public" ρόλο να δημιουργεί πίνακες
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Για τον Terraform Generator
ALTER TABLE terraform_jobs OWNER TO tf_user;

-- Για τον Repo Analyzer (αν χρειαστεί)
ALTER TABLE analysis_jobs OWNER TO an_user;

-- Για τον Ansible Generator (προληπτικά)
ALTER TABLE ansible_jobs OWNER TO as_user;

-- Για τον Pipeline Generator
ALTER TABLE pipeline_jobs OWNER TO pp_user;