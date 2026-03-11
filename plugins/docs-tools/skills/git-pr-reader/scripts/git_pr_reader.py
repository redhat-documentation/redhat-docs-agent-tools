#!/usr/bin/env python3
"""
Git PR Reader Script for Claude Code Skill

Extracts code changes from GitHub Pull Requests and GitLab Merge Requests
for release note generation. Auto-detects platform, fetches metadata and diffs,
and filters out irrelevant files.

Usage:
    python git_pr_reader.py --url "https://github.com/owner/repo/pull/123"
    python git_pr_reader.py --url "https://gitlab.com/group/project/-/merge_requests/456"
    python git_pr_reader.py --url "https://github.com/owner/repo/pull/123" --format markdown
"""

import os
import sys
import json
import yaml
import argparse
import urllib3
import pathlib
import re
from typing import Dict, List, Optional, Tuple

try:
    from github import Github, Auth
except ImportError:
    print(json.dumps({"error": "PyGithub not installed. Run: python3 -m pip install PyGithub"}))
    sys.exit(1)

try:
    from gitlab import Gitlab
except ImportError:
    print(json.dumps({"error": "python-gitlab not installed. Run: python3 -m pip install python-gitlab"}))
    sys.exit(1)


class GitPRReader:
    """Read-only Git PR/MR client for fetching code changes."""

    def __init__(self, config_path: Optional[str] = None):
        """
        Initialize Git PR Reader.

        Args:
            config_path: Path to git_filters.yaml (default: auto-detect)
        """
        if config_path is None:
            # Auto-detect config path relative to script location
            script_dir = pathlib.Path(__file__).parent.parent
            config_path = script_dir / "config" / "git_filters.yaml"

        self.config_path = config_path
        self.filters = self._load_filters()

    def _load_filters(self) -> List[re.Pattern]:
        """Load file filtering patterns from config."""
        if not os.path.exists(self.config_path):
            # Return empty list if no config (no filtering)
            return []

        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)

        patterns = config.get('exclude_patterns', [])
        return [re.compile(pattern) for pattern in patterns]

    def _should_include_file(self, filename: str) -> bool:
        """
        Check if file should be included based on filter patterns.

        Args:
            filename: File path to check

        Returns:
            True if file should be included, False if filtered out
        """
        if not self.filters:
            return True

        return not any(regex.search(filename) for regex in self.filters)

    def _parse_url(self, url: str) -> Tuple[str, str, Dict[str, str]]:
        """
        Parse Git URL to determine platform and extract components.

        Args:
            url: GitHub PR or GitLab MR URL

        Returns:
            Tuple of (platform, base_url, components_dict)
        """
        parsed = urllib3.util.parse_url(url)
        host = parsed.host or ""

        if "github" in host:
            return "github", f"{parsed.scheme}://{host}", self._parse_github_url(parsed)
        elif "gitlab" in host:
            return "gitlab", f"{parsed.scheme}://{host}", self._parse_gitlab_url(parsed)
        else:
            raise ValueError(f"Unable to determine if URL is GitHub or GitLab: {url}")

    def _parse_github_url(self, parsed_url) -> Dict[str, str]:
        """Extract owner, repo, and PR number from GitHub URL."""
        parts = pathlib.Path(parsed_url.path).parts

        if len(parts) < 5 or parts[3] != 'pull':
            raise ValueError(f"Invalid GitHub PR URL format: {parsed_url.url}")

        return {
            'owner': parts[1],
            'repo': parts[2],
            'pull_number': parts[4]
        }

    def _parse_gitlab_url(self, parsed_url) -> Dict[str, str]:
        """Extract namespace and MR ID from GitLab URL."""
        parts = pathlib.Path(parsed_url.path).parts

        try:
            mr_index = parts.index('merge_requests')
        except ValueError:
            raise ValueError(f"Invalid GitLab MR URL format: {parsed_url.url}")

        # Extract namespace (everything between start and 'merge_requests', excluding '-')
        namespace_parts = [p for p in parts[1:mr_index] if p != '-']
        namespace = '/'.join(namespace_parts)

        mr_id = parts[-1]

        return {
            'namespace': namespace,
            'mr_id': mr_id
        }

    def _get_github_pr(self, url: str, components: Dict[str, str]) -> Dict:
        """
        Fetch GitHub Pull Request data.

        Args:
            url: Original PR URL
            components: Parsed URL components

        Returns:
            Dictionary with PR metadata and diffs
        """
        token = os.environ.get('GITHUB_TOKEN')

        if token:
            auth = Auth.Token(token)
            g = Github(auth=auth)
        else:
            g = Github()

        repo = g.get_repo(f"{components['owner']}/{components['repo']}")
        pr = repo.get_pull(int(components['pull_number']))

        # Get PR metadata
        title = pr.title
        description = pr.body or ""

        # Get files with pagination support
        files = self._get_github_pr_files(pr, repo)

        # Extract diffs with filtering
        diffs = []
        total_files = len(files)
        filtered_count = 0

        for file_data in files:
            filename = file_data.get('filename', '')

            if not self._should_include_file(filename):
                filtered_count += 1
                continue

            # Only include files that have a patch (diff)
            if 'patch' in file_data:
                diffs.append({
                    'filename': filename,
                    'diff': file_data['patch']
                })

        return {
            'git_type': 'github',
            'url': url,
            'title': title,
            'description': description,
            'diffs': diffs,
            'stats': {
                'total_files': total_files,
                'filtered_files': filtered_count,
                'included_files': len(diffs)
            }
        }

    def _get_github_pr_files(self, pr, repo) -> List[Dict]:
        """
        Fetch all files from GitHub PR with pagination.

        Args:
            pr: GitHub PR object
            repo: GitHub repository object

        Returns:
            List of file dictionaries
        """
        files_url = pr.url + '/files'
        files = []
        per_page = 100
        page = 1
        max_pages = 10  # Safety limit: max 1000 files

        while page <= max_pages:
            headers_out, data = repo._requester.requestJsonAndCheck(
                "GET",
                files_url,
                parameters={"per_page": per_page, 'page': page},
            )

            if not data:
                break

            files.extend(data)

            if len(data) < per_page:
                break

            page += 1

        return files

    def _get_gitlab_mr(self, url: str, base_url: str, components: Dict[str, str]) -> Dict:
        """
        Fetch GitLab Merge Request data.

        Args:
            url: Original MR URL
            base_url: GitLab instance base URL
            components: Parsed URL components

        Returns:
            Dictionary with MR metadata and diffs
        """
        token = os.environ.get('GITLAB_TOKEN')

        if token:
            gl = Gitlab(url=base_url, private_token=token, ssl_verify=True)
        else:
            gl = Gitlab(url=base_url, ssl_verify=True)

        project = gl.projects.get(components['namespace'])
        mr = project.mergerequests.get(components['mr_id'])

        # Get MR metadata
        title = mr.title
        description = mr.description or ""

        # Get changes
        changes = mr.changes()
        file_diffs = changes.get('changes', [])

        # Extract diffs with filtering
        diffs = []
        total_files = len(file_diffs)
        filtered_count = 0

        for file_data in file_diffs:
            filename = file_data.get('new_path', '')

            if not self._should_include_file(filename):
                filtered_count += 1
                continue

            diffs.append({
                'filename': filename,
                'diff': file_data.get('diff', '')
            })

        return {
            'git_type': 'gitlab',
            'url': url,
            'title': title,
            'description': description,
            'diffs': diffs,
            'stats': {
                'total_files': total_files,
                'filtered_files': filtered_count,
                'included_files': len(diffs)
            }
        }

    def get_pr_data(self, url: str, apply_filters: bool = True) -> Dict:
        """
        Fetch PR/MR data from GitHub or GitLab.

        Args:
            url: GitHub PR or GitLab MR URL
            apply_filters: Whether to apply file filtering

        Returns:
            Dictionary with PR/MR data and diffs
        """
        # Temporarily disable filters if requested
        original_filters = self.filters
        if not apply_filters:
            self.filters = []

        try:
            platform, base_url, components = self._parse_url(url)

            if platform == "github":
                return self._get_github_pr(url, components)
            else:  # gitlab
                return self._get_gitlab_mr(url, base_url, components)

        except Exception as e:
            return {
                'error': f"Failed to fetch PR/MR from {url}: {str(e)}",
                'url': url
            }
        finally:
            # Restore original filters
            self.filters = original_filters


def format_markdown(data: Dict) -> str:
    """
    Format PR/MR data as Markdown.

    Args:
        data: PR/MR data dictionary

    Returns:
        Markdown formatted string
    """
    if 'error' in data:
        return f"# Error\n\n{data['error']}"

    output = []

    # Header
    output.append(f"# {data['title']}\n")
    output.append(f"**Source:** {data['url']}")
    output.append(f"**Type:** {'GitHub Pull Request' if data['git_type'] == 'github' else 'GitLab Merge Request'}\n")

    # Description
    if data.get('description'):
        output.append("## Description\n")
        output.append(data['description'])
        output.append("")

    # Stats
    stats = data.get('stats', {})
    total = stats.get('total_files', 0)
    included = stats.get('included_files', 0)
    output.append(f"## Changed Files ({included} of {total} total)\n")

    # Diffs
    for diff_data in data.get('diffs', []):
        output.append(f"### {diff_data['filename']}")
        output.append("```diff")
        output.append(diff_data['diff'])
        output.append("```\n")

    return '\n'.join(output)


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Extract code changes from GitHub PRs and GitLab MRs"
    )
    parser.add_argument(
        '--url',
        required=True,
        help='GitHub PR or GitLab MR URL'
    )
    parser.add_argument(
        '--no-filter',
        action='store_true',
        help='Disable file filtering (include all files)'
    )
    parser.add_argument(
        '--format',
        choices=['json', 'markdown'],
        default='json',
        help='Output format (default: json)'
    )
    parser.add_argument(
        '--config',
        help='Path to git_filters.yaml (default: auto-detect)'
    )

    args = parser.parse_args()

    try:
        reader = GitPRReader(config_path=args.config)
        result = reader.get_pr_data(args.url, apply_filters=not args.no_filter)

        if args.format == 'markdown':
            print(format_markdown(result))
        else:
            print(json.dumps(result, indent=2))

    except Exception as e:
        print(json.dumps({"error": f"Unexpected error: {str(e)}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()
