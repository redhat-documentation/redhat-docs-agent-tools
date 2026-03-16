#!/usr/bin/env python3
"""
JIRA Writer Script for Claude Code Skill

This script provides write access to JIRA issues on Red Hat Issue Tracker.
It can update release notes, custom fields, and issue status.

Usage:
    python jira_writer.py --issue COO-1145 --release-note "Fixed bug..."
    python jira_writer.py --issue COO-1145 --status Proposed
    python jira_writer.py --issue COO-1145 --custom-field customfield_12317313 --value "Content"
"""

import os
import sys
import json
import argparse
from ratelimit import limits, sleep_and_retry

try:
    from jira import JIRA
except ImportError:
    print(json.dumps({"error": "jira package not installed. Run: python3 -m pip install jira"}))
    sys.exit(1)


def load_env_file():
    """Load environment variables from ~/.env file."""
    env_file = os.path.expanduser("~/.env")
    if os.path.exists(env_file):
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    os.environ.setdefault(key.strip(), value.strip())


# Custom field IDs used in Red Hat JIRA
CUSTOM_FIELD_RELEASE_NOTE_CONTENT = 'customfield_10783'
CUSTOM_FIELD_RELEASE_NOTE_STATUS = 'customfield_10807'


class JiraWriter:
    """Write-enabled JIRA client for updating issues."""

    def __init__(self, server=None):
        """Initialize JIRA connection with appropriate authentication."""
        load_env_file()

        token = os.environ.get('JIRA_AUTH_TOKEN')
        if not token:
            raise ValueError("JIRA_AUTH_TOKEN environment variable not set. Add it to ~/.env")

        server = server or os.environ.get('JIRA_URL', 'https://redhat.atlassian.net')

        if 'atlassian.net' in server:
            email = os.environ.get('JIRA_EMAIL')
            if not email:
                raise ValueError("JIRA_EMAIL environment variable not set. Required for Atlassian Cloud. Add it to ~/.env")
            self.jira = JIRA(server=server, basic_auth=(email, token))
        else:
            self.jira = JIRA(server=server, token_auth=token)

        self.server = server

    @sleep_and_retry
    @limits(calls=2, period=5)
    def update_issue(self, jira_id, fields_to_update):
        """
        Update fields on a JIRA issue.

        Args:
            jira_id: JIRA issue key (e.g., "COO-1145")
            fields_to_update: Dictionary of field IDs/names and their new values

        Returns:
            Dictionary with update results
        """
        try:
            issue = self.jira.issue(jira_id)

            # Update the issue with new field values
            issue.update(fields=fields_to_update)

            return {
                "success": True,
                "issue_key": jira_id,
                "updated_fields": fields_to_update,
                "url": f"{self.server}/browse/{jira_id}"
            }

        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to update issue {jira_id}: {str(e)}",
                "issue_key": jira_id
            }

    def push_release_note(self, jira_id, release_note, status="Proposed"):
        """
        Push a release note to a JIRA issue.

        This updates the release note content field and optionally the status.

        Args:
            jira_id: JIRA issue key
            release_note: Release note text content
            status: Release note status (default: "Proposed")

        Returns:
            Dictionary with update results
        """
        fields = {
            CUSTOM_FIELD_RELEASE_NOTE_CONTENT: release_note,
            CUSTOM_FIELD_RELEASE_NOTE_STATUS: {'value': status}
        }

        return self.update_issue(jira_id, fields)

    def update_release_note_status(self, jira_id, status):
        """
        Update only the release note status field.

        Args:
            jira_id: JIRA issue key
            status: New status value (Proposed, Approved, Rejected)

        Returns:
            Dictionary with update results
        """
        fields = {
            CUSTOM_FIELD_RELEASE_NOTE_STATUS: {'value': status}
        }

        return self.update_issue(jira_id, fields)

    def update_custom_field(self, jira_id, field_id, value):
        """
        Update a single custom field.

        Args:
            jira_id: JIRA issue key
            field_id: Custom field ID (e.g., "customfield_12317313")
            value: New value for the field

        Returns:
            Dictionary with update results
        """
        fields = {field_id: value}

        return self.update_issue(jira_id, fields)


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Update JIRA issues on Red Hat Issue Tracker"
    )
    parser.add_argument(
        '--issue',
        action='append',
        required=True,
        help='JIRA issue key (e.g., COO-1145). Can be specified multiple times for batch updates.'
    )
    parser.add_argument(
        '--release-note',
        help='Release note content to push to the issue'
    )
    parser.add_argument(
        '--release-note-file',
        help='Path to file containing release note content'
    )
    parser.add_argument(
        '--status',
        choices=['Proposed', 'Approved', 'Rejected', 'Not Required'],
        help='Release note status'
    )
    parser.add_argument(
        '--custom-field',
        help='Custom field ID to update (e.g., customfield_12317313)'
    )
    parser.add_argument(
        '--value',
        help='Value for the custom field'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be updated without making changes'
    )

    args = parser.parse_args()

    # Validate arguments
    has_release_note = args.release_note or args.release_note_file
    has_status = args.status is not None
    has_custom_field = args.custom_field and args.value

    if not (has_release_note or has_status or has_custom_field):
        parser.error("Must specify one of: --release-note, --release-note-file, --status, or --custom-field with --value")

    if args.custom_field and not args.value:
        parser.error("--custom-field requires --value")

    if args.value and not args.custom_field:
        parser.error("--value requires --custom-field")

    # Read release note from file if specified
    release_note = args.release_note
    if args.release_note_file:
        try:
            with open(args.release_note_file, 'r') as f:
                release_note = f.read()
        except Exception as e:
            print(json.dumps({"error": f"Failed to read file {args.release_note_file}: {str(e)}"}))
            sys.exit(1)

    try:
        writer = JiraWriter()
        results = []

        for issue_key in args.issue:
            if args.dry_run:
                result = {
                    "dry_run": True,
                    "issue_key": issue_key,
                    "would_update": {}
                }

                if release_note:
                    result["would_update"][CUSTOM_FIELD_RELEASE_NOTE_CONTENT] = release_note[:100] + "..." if len(release_note) > 100 else release_note

                if args.status:
                    result["would_update"][CUSTOM_FIELD_RELEASE_NOTE_STATUS] = args.status

                if args.custom_field:
                    result["would_update"][args.custom_field] = args.value[:100] + "..." if isinstance(args.value, str) and len(args.value) > 100 else args.value

                results.append(result)

            else:
                # Perform actual updates
                if release_note and args.status:
                    # Push release note with status
                    result = writer.push_release_note(issue_key, release_note, args.status)
                elif release_note:
                    # Push release note with default status
                    result = writer.push_release_note(issue_key, release_note)
                elif args.status:
                    # Update only status
                    result = writer.update_release_note_status(issue_key, args.status)
                elif args.custom_field:
                    # Update custom field
                    result = writer.update_custom_field(issue_key, args.custom_field, args.value)

                results.append(result)

        # Output results as JSON
        if len(results) == 1:
            print(json.dumps(results[0], indent=2))
        else:
            print(json.dumps(results, indent=2))

        # Exit with error code if any updates failed
        if any(not r.get('success', True) and not r.get('dry_run') for r in results):
            sys.exit(1)

    except ValueError as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": f"Unexpected error: {str(e)}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()
