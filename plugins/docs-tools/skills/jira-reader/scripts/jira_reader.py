#!/usr/bin/env python3
"""
JIRA Reader Script for Claude Code Skill

This script provides read-only access to JIRA issues on Red Hat Issue Tracker.
It fetches issue details, comments, custom fields, and related Git links.

Usage:
    python jira_reader.py --issue COO-1145
    python jira_reader.py --issue COO-1145 --include-comments
    python jira_reader.py --jql "project=COO AND fixVersion='1.3.0 RC'"
"""

import os
import sys
import json
import argparse
import urllib3
from datetime import datetime
from ratelimit import limits, sleep_and_retry

try:
    from jira import JIRA
except ImportError:
    print(json.dumps({"error": "jira package not installed. Run: python3 -m pip install jira"}))
    sys.exit(1)


class JiraReader:
    """Read-only JIRA client for fetching and analyzing issues."""

    def __init__(self, server=None):
        """Initialize JIRA connection with token authentication."""
        token = os.environ.get('JIRA_AUTH_TOKEN')
        if not token:
            raise ValueError("JIRA_AUTH_TOKEN environment variable not set. Add it to ~/.env")

        server = server or os.environ.get('JIRA_URL', 'https://issues.redhat.com')
        self.jira = JIRA(server=server, token_auth=token)
        self.server = server

    def process_comments(self, comments):
        """
        Process JIRA comments into anonymized threaded format.

        Args:
            comments: List of JIRA comment objects

        Returns:
            List of dictionaries with anonymized comment data
        """
        if not comments:
            return []

        # Create user mapping for anonymization
        user_mapping = {}
        participant_counter = 0

        # Sort comments by creation date
        sorted_comments = sorted(comments, key=lambda x: x.created)

        processed_comments = []

        for comment in sorted_comments:
            # Get or create anonymous participant label
            author_key = comment.author.key if hasattr(comment.author, 'key') else str(comment.author)
            if author_key not in user_mapping:
                participant_counter += 1
                user_mapping[author_key] = f"Participant {chr(64 + participant_counter)}"  # A, B, C, etc.

            participant = user_mapping[author_key]

            # Format timestamp
            try:
                timestamp = datetime.strptime(comment.created[:19], '%Y-%m-%dT%H:%M:%S')
                formatted_time = timestamp.strftime('%Y-%m-%d %H:%M')
            except:
                formatted_time = comment.created[:16].replace('T', ' ')

            # Clean comment body
            comment_body = comment.body.strip() if comment.body else ""

            if comment_body:
                processed_comments.append({
                    "participant": participant,
                    "timestamp": formatted_time,
                    "body": comment_body
                })

        return processed_comments

    def extract_git_links(self, links, git_link_types="all"):
        """
        Extract Git-related links (GitHub/GitLab) from JIRA remote links.

        Args:
            links: List of JIRA remote link objects
            git_link_types: Filter for "github", "gitlab", or "all"

        Returns:
            List of Git URLs
        """
        links_list = []

        if git_link_types == "github":
            prefix = ("github", "www.github")
        elif git_link_types == "gitlab":
            prefix = ("gitlab",)
        else:
            prefix = ("github", "www.github", "gitlab")

        for link in links:
            try:
                host = urllib3.util.parse_url(link.object.url).host
                if host and host.startswith(prefix):
                    links_list.append(link.object.url)
            except:
                continue

        return links_list

    def categorize_issue_type(self, issue_type):
        """
        Categorize issue type into standard categories.

        Args:
            issue_type: JIRA issue type string

        Returns:
            Standardized category
        """
        issue_type_lower = issue_type.lower()

        if issue_type_lower == "bug":
            return "Bug"
        elif issue_type_lower == "vulnerability":
            return "CVE"
        elif issue_type_lower in ["story", "feature"]:
            return "Feature/Story"
        elif issue_type_lower == "epic":
            return "Epic"
        elif issue_type_lower == "task":
            return "Task"
        else:
            return issue_type

    @sleep_and_retry
    @limits(calls=2, period=5)
    def get_issue_data(self, jira_id, include_comments=False, git_link_types="all"):
        """
        Fetch comprehensive data for a JIRA issue.

        Args:
            jira_id: JIRA issue key (e.g., "COO-1145")
            include_comments: Whether to fetch and process comments
            git_link_types: Filter for Git links ("github", "gitlab", or "all")

        Returns:
            Dictionary with issue data
        """
        try:
            issue = self.jira.issue(jira_id)
            links = self.jira.remote_links(jira_id)

            # Get comments if requested
            comments_data = []
            if include_comments:
                comments = self.jira.comments(jira_id)
                comments_data = self.process_comments(comments)

            # Extract Git links
            git_links = self.extract_git_links(links, git_link_types)

            # Extract custom fields
            custom_fields = {}

            # Release Note Type (customfield_12320850)
            if hasattr(issue.fields, 'customfield_12320850') and issue.fields.customfield_12320850:
                release_note_type = issue.fields.customfield_12320850.value
                # Normalize "Feature" to "Enhancement"
                release_note_type = "Enhancement" if release_note_type == "Feature" else release_note_type
                custom_fields['release_note_type'] = release_note_type

            # Fix Versions
            if issue.fields.fixVersions:
                custom_fields['fix_versions'] = [v.name for v in issue.fields.fixVersions]

            # Extract assignee safely
            assignee = None
            if issue.fields.assignee:
                assignee = issue.fields.assignee.displayName if hasattr(issue.fields.assignee, 'displayName') else str(issue.fields.assignee)

            # Build response
            return {
                "issue_key": issue.key,
                "issue_type": str(issue.fields.issuetype),
                "issue_category": self.categorize_issue_type(str(issue.fields.issuetype)),
                "priority": str(issue.fields.priority) if issue.fields.priority else "Undefined",
                "status": str(issue.fields.status),
                "assignee": assignee,
                "summary": issue.fields.summary,
                "description": issue.fields.description or "",
                "created": issue.fields.created,
                "updated": issue.fields.updated,
                "comments": comments_data,
                "custom_fields": custom_fields,
                "git_links": git_links,
                "url": f"{self.server}/browse/{issue.key}"
            }

        except Exception as e:
            return {
                "error": f"Failed to fetch issue {jira_id}: {str(e)}",
                "issue_key": jira_id
            }

    @sleep_and_retry
    @limits(calls=2, period=5)
    def search_issues(self, jql, max_results=50, fetch_details=False):
        """
        Search JIRA issues using JQL (JIRA Query Language).

        Args:
            jql: JQL query string
            max_results: Maximum number of results to return
            fetch_details: If True, return issue keys for detailed fetching; if False, return summary info

        Returns:
            List of issue keys (if fetch_details=True) or list of issue summaries (if fetch_details=False)
        """
        try:
            issues = self.jira.search_issues(jql, maxResults=max_results)

            if not fetch_details:
                # Return basic info from search results without additional API calls (FAST)
                summaries = []
                for issue in issues:
                    assignee = None
                    if issue.fields.assignee:
                        assignee = issue.fields.assignee.displayName if hasattr(issue.fields.assignee, 'displayName') else str(issue.fields.assignee)

                    # Extract fix versions
                    fix_versions = []
                    if issue.fields.fixVersions:
                        fix_versions = [v.name for v in issue.fields.fixVersions]

                    summaries.append({
                        "issue_key": issue.key,
                        "issue_type": str(issue.fields.issuetype),
                        "issue_category": self.categorize_issue_type(str(issue.fields.issuetype)),
                        "priority": str(issue.fields.priority) if issue.fields.priority else "Undefined",
                        "status": str(issue.fields.status),
                        "assignee": assignee,
                        "summary": issue.fields.summary,
                        "fix_versions": fix_versions,
                        "url": f"{self.server}/browse/{issue.key}"
                    })
                return summaries
            else:
                # Return issue keys for detailed fetching (SLOW but comprehensive)
                return [issue.key for issue in issues]
        except Exception as e:
            return {"error": f"JQL search failed: {str(e)}"}


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Fetch and analyze JIRA issues from Red Hat Issue Tracker"
    )
    parser.add_argument(
        '--issue',
        action='append',
        help='JIRA issue key (e.g., COO-1145). Can be specified multiple times.'
    )
    parser.add_argument(
        '--jql',
        help='JQL query to search for issues'
    )
    parser.add_argument(
        '--include-comments',
        action='store_true',
        help='Include anonymized comment threads'
    )
    parser.add_argument(
        '--git-links',
        choices=['github', 'gitlab', 'all'],
        default='all',
        help='Filter Git links by type'
    )
    parser.add_argument(
        '--max-results',
        type=int,
        default=50,
        help='Maximum number of results for JQL search (default: 50)'
    )
    parser.add_argument(
        '--fetch-details',
        action='store_true',
        help='Fetch full details for each issue (slow). By default, JQL searches return fast summaries only.'
    )

    args = parser.parse_args()

    # Validate arguments
    if not args.issue and not args.jql:
        parser.error("Must specify either --issue or --jql")

    try:
        reader = JiraReader()

        results = []

        # Handle JQL search
        if args.jql:
            search_results = reader.search_issues(args.jql, args.max_results, fetch_details=args.fetch_details)
            if isinstance(search_results, dict) and 'error' in search_results:
                print(json.dumps(search_results, indent=2))
                sys.exit(1)

            if args.fetch_details:
                # search_results contains issue keys, fetch details for each
                for issue_key in search_results:
                    issue_data = reader.get_issue_data(
                        issue_key,
                        include_comments=args.include_comments,
                        git_link_types=args.git_links
                    )
                    results.append(issue_data)
            else:
                # search_results already contains summaries, use directly
                results = search_results

        # Handle individual issue requests
        elif args.issue:
            for issue_key in args.issue:
                issue_data = reader.get_issue_data(
                    issue_key,
                    include_comments=args.include_comments,
                    git_link_types=args.git_links
                )
                results.append(issue_data)

        # Output results as JSON
        if len(results) == 1:
            print(json.dumps(results[0], indent=2))
        else:
            print(json.dumps(results, indent=2))

    except ValueError as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": f"Unexpected error: {str(e)}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()
