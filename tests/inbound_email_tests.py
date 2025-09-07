#!/usr/bin/env python3
"""
Integration tests for inbound email functionality.

This test script:
1. Set required variables in the environment
2. Runs "supabase db reset" to reset the database
3. Sends all .eml files in tests/email_data to the supabase inbound-email function
"""

import os
import subprocess
import sys
from pathlib import Path
from typing import List

import psycopg2
import pytest


class TestInboundEmail:
    """Integration tests for inbound email processing."""

    def test_inbound_email_integration(self):
        """
        Run the complete inbound email integration test in order:
        1. Set environment variables
        2. Reset database
        3. Send all email files

        If any step fails, the test stops and doesn't continue.
        """
        print("Running inbound email integration test...")
        print("=" * 50)

        # Step 1: Set environment variables
        print("1. Setting environment variables...")
        self._set_environment_variables()
        print("✓ All required environment variables are set")
        print()

        # Step 2: Reset database
        print("2. Resetting database...")
        self._reset_database()
        print("✓ Database reset completed successfully")
        print()

        # Step 3: Send email files
        print("3. Sending email files...")
        sent_emails_count = self._send_all_eml_files()
        print("✓ All email files sent successfully")
        print()

        # Step 4: Verify database state
        print("4. Verifying database state...")
        self._verify_database_state(sent_emails_count)
        print("✓ Database verification completed successfully")
        print()

        print("=" * 50)
        print("✓ All integration test steps completed successfully!")

    def _set_environment_variables(self):
        """Set the required environment variables for testing."""
        env_vars = {
            "POSTMARK_BASIC_USER": "postmark-basic-user",
            "POSTMARK_BASIC_PASSWORD": "postmark-basic-password",
            "POSTMARK_ALLOWED_IPS": "127.0.0.1",
            "INBOUND_EMAIL_DOMAIN": "in.emailinator.app",
            "SUPABASE_URL": "http://127.0.0.1:54321",
        }

        for var_name, var_value in env_vars.items():
            os.environ[var_name] = var_value

    def _reset_database(self):
        """Reset the local supabase database using test seed data."""
        # Get paths
        project_root = Path(__file__).parent.parent
        supabase_seed_path = project_root / "supabase" / "seed.sql"
        test_seed_path = project_root / "tests" / "inbound_email_tests_seed.sql"
        backup_seed_path = project_root / "supabase" / "seed.sql.backup"

        # Check if test seed file exists
        if not test_seed_path.exists():
            pytest.fail(f"Test seed file not found: {test_seed_path}")

        original_seed_existed = supabase_seed_path.exists()

        try:
            # Step 1: Backup existing seed.sql if it exists
            if original_seed_existed:
                import shutil

                shutil.copy2(supabase_seed_path, backup_seed_path)
                print(f"  Backed up existing seed.sql to {backup_seed_path}")

            # Step 2: Copy test seed to supabase/seed.sql
            import shutil

            shutil.copy2(test_seed_path, supabase_seed_path)
            print(f"  Replaced seed.sql with test seed from {test_seed_path}")

            # Step 3: Run supabase db reset
            result = subprocess.run(
                ["supabase", "db", "reset"],
                capture_output=True,
                text=True,
                timeout=60,
            )

            # Check result but don't fail yet - we need to restore first
            reset_failed = result.returncode != 0
            reset_error_info = None
            if reset_failed:
                reset_error_info = (
                    f"supabase db reset failed with return code {result.returncode}\n"
                    f"stdout: {result.stdout}\n"
                    f"stderr: {result.stderr}"
                )

        except subprocess.TimeoutExpired:
            reset_failed = True
            reset_error_info = "supabase db reset timed out after 60 seconds"
        except FileNotFoundError:
            reset_failed = True
            reset_error_info = "supabase CLI not found. Please install Supabase CLI."
        finally:
            # Step 4: Always restore original seed.sql
            try:
                if original_seed_existed and backup_seed_path.exists():
                    import shutil

                    shutil.move(backup_seed_path, supabase_seed_path)
                    print(f"  Restored original seed.sql from backup")
                elif not original_seed_existed and supabase_seed_path.exists():
                    # Remove the test seed file if no original existed
                    supabase_seed_path.unlink()
                    print(f"  Removed test seed.sql (no original existed)")

                # Clean up backup file if it still exists
                if backup_seed_path.exists():
                    backup_seed_path.unlink()

            except Exception as restore_error:
                print(
                    f"  Warning: Failed to restore original seed.sql: {restore_error}"
                )

        # Now fail if the reset failed
        if reset_failed:
            pytest.fail(reset_error_info)

    def _send_all_eml_files(self):
        """Send all .eml files in tests/email_data to supabase."""
        # Get the project root directory
        project_root = Path(__file__).parent.parent
        email_data_dir = project_root / "tests" / "email_data"

        if not email_data_dir.exists():
            pytest.fail(f"Email data directory not found: {email_data_dir}")

        # Find all .eml files
        eml_files = list(email_data_dir.glob("*.eml"))

        if not eml_files:
            pytest.fail(f"No .eml files found in {email_data_dir}")

        print(f"Found {len(eml_files)} .eml files to process")

        # Get environment variables
        supabase_url = os.getenv("SUPABASE_URL")
        inbound_domain = os.getenv("INBOUND_EMAIL_DOMAIN")

        # Construct the URL for the inbound-email function
        function_url = f"{supabase_url}/functions/v1/inbound-email"

        # Test alias (using the inbound domain)
        test_alias = f"test@{inbound_domain}"

        successful_sends = 0
        failed_sends = []

        for eml_file in eml_files:
            try:
                print(f"Sending {eml_file.name}...")

                # Run the send_to_supabase script
                result = subprocess.run(
                    [
                        sys.executable,
                        "-m",
                        "tools.send_to_supabase",
                        "--file",
                        str(eml_file),
                        "--url",
                        function_url,
                        "--alias",
                        test_alias,
                    ],
                    capture_output=True,
                    text=True,
                    timeout=30,
                    cwd=project_root,
                )

                if result.returncode == 0:
                    successful_sends += 1
                    print(f"  ✓ Successfully sent {eml_file.name}")
                else:
                    failed_sends.append(
                        {
                            "file": eml_file.name,
                            "return_code": result.returncode,
                            "stdout": result.stdout,
                            "stderr": result.stderr,
                        }
                    )
                    print(f"  ✗ Failed to send {eml_file.name}")

            except subprocess.TimeoutExpired:
                failed_sends.append(
                    {"file": eml_file.name, "error": "Timeout after 30 seconds"}
                )
                print(f"  ✗ Timeout sending {eml_file.name}")
            except Exception as e:
                failed_sends.append({"file": eml_file.name, "error": str(e)})
                print(f"  ✗ Error sending {eml_file.name}: {e}")

        print(f"\nResults: {successful_sends} successful, {len(failed_sends)} failed")

        if failed_sends:
            error_details = "\n".join(
                [
                    f"- {fail['file']}: {fail.get('error', f'Return code {fail.get('return_code')}')} "
                    f"{fail.get('stderr', '')}"
                    for fail in failed_sends
                ]
            )
            pytest.fail(f"Failed to send {len(failed_sends)} files:\n{error_details}")

        return successful_sends

    def _verify_database_state(self, expected_email_count):
        """Verify that the database has been updated correctly after processing emails."""
        try:
            # Connect to the local Supabase database using psycopg2
            conn = psycopg2.connect(
                user="postgres",
                password="postgres",
                host="127.0.0.1",
                port="54322",
                dbname="postgres",
            )

            cursor = conn.cursor()

            # Check raw_emails table count
            cursor.execute("SELECT COUNT(*) FROM raw_emails;")
            raw_emails_count = cursor.fetchone()[0]

            # Check raw_emails with UPDATED_TASKS status
            cursor.execute(
                "SELECT COUNT(*) FROM raw_emails WHERE status = 'UPDATED_TASKS';"
            )
            raw_emails_updated_tasks_count = cursor.fetchone()[0]

            # Check tasks table count
            cursor.execute("SELECT COUNT(*) FROM tasks;")
            tasks_count = cursor.fetchone()[0]

            cursor.close()
            conn.close()

            # Verify the counts
            verification_errors = []

            if raw_emails_count != expected_email_count:
                verification_errors.append(
                    f"Expected {expected_email_count} rows in raw_emails, got {raw_emails_count}"
                )
            else:
                print(f"  ✓ raw_emails table has {raw_emails_count} rows")

            if raw_emails_updated_tasks_count != expected_email_count:
                verification_errors.append(
                    f"Expected all {expected_email_count} raw_emails to have UPDATED_TASKS status, got {raw_emails_updated_tasks_count}"
                )
            else:
                print(
                    f"  ✓ All {raw_emails_updated_tasks_count} raw_emails have UPDATED_TASKS status"
                )

            if tasks_count < 1:
                verification_errors.append(
                    f"Expected at least 1 row in tasks, got {tasks_count}"
                )
            else:
                print(f"  ✓ tasks table has {tasks_count} rows")

            if verification_errors:
                pytest.fail(
                    "Database verification failed:\n"
                    + "\n".join([f"- {error}" for error in verification_errors])
                )

        except psycopg2.Error as e:
            pytest.fail(f"Database connection/query failed: {e}")
        except Exception as e:
            pytest.fail(f"Database verification failed with error: {e}")


def run_integration_tests():
    """Run the integration tests as a standalone script."""
    # Change to the project root directory
    project_root = Path(__file__).parent.parent
    os.chdir(project_root)

    test_instance = TestInboundEmail()

    try:
        # Run the complete integration test
        test_instance.test_inbound_email_integration()

    except Exception as e:
        print(f"✗ Test failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    run_integration_tests()
