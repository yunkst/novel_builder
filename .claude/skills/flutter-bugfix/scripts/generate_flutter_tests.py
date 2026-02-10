#!/usr/bin/env python3
"""
Flutter Bug Fix Test Generator

Generates test file templates for Flutter bug fixing workflow.
"""

import os
import sys
from pathlib import Path


def generate_bug_test(bug_name, test_description, project_root=None):
    """
    Generate a bug reproduction test file

    Args:
        bug_name: Name of the bug (e.g., "blank-screen", "stale-data")
        test_description: Description of what the bug is
        project_root: Path to Flutter project root (optional)
    """
    if project_root is None:
        project_root = Path.cwd()
    else:
        project_root = Path(project_root)

    # Create test directory
    test_dir = project_root / "test" / "bugs"
    test_dir.mkdir(parents=True, exist_ok=True)

    # Generate test file name
    test_file = test_dir / f"{bug_name}_test.dart"

    # Generate test content
    test_content = f"""import 'package:flutter_test/flutter_test.dart';

/// {bug_name} Bug Reproduction Test
///
/// Bug Description: {test_description}
///
/// This test file reproduces the bug and validates the fix.
void main() {{
  group('{bug_name.replace("-", " ").title()} - Bug Reproduction', () {{
    test('Should describe expected behavior', () {{
      // Arrange
      // Set up test data and conditions

      // Act
      // Execute the code that should be tested

      // Assert
      // Verify the expected behavior
      expect(true, isTrue, reason: 'Test not yet implemented');
    }});

    test('Should handle edge case 1', () {{
      // Test edge case scenario
      expect(true, isTrue, reason: 'Test not yet implemented');
    }});

    test('Should handle edge case 2', () {{
      // Test another edge case
      expect(true, isTrue, reason: 'Test not yet implemented');
    }});
  }});
}}
"""

    # Write test file
    with open(test_file, 'w', encoding='utf-8') as f:
        f.write(test_content)

    print(f"✅ Created bug test file: {{test_file.relative_to(project_root)}}")

    return test_file


def generate_fix_verification_test(bug_name, fixes_applied, project_root=None):
    """
    Generate a fix verification test file

    Args:
        bug_name: Name of the bug
        fixes_applied: List of fix descriptions
        project_root: Path to Flutter project root (optional)
    """
    if project_root is None:
        project_root = Path.cwd()
    else:
        project_root = Path(project_root)

    # Create test directory
    test_dir = project_root / "test" / "bugs"
    test_dir.mkdir(parents=True, exist_ok=True)

    # Generate test file name
    test_file = test_dir / f"{bug_name}_fix_verification_test.dart"

    # Generate test content
    fixes_text = "\n".join([f"  // - {fix}" for fix in fixes_applied])

    test_content = f"""import 'package:flutter_test/flutter_test.dart';

/// {bug_name.replace("-", " ").title()} Fix Verification Test
///
/// This test verifies that the bug fix works correctly.
///
/// Fixes Applied:
{fixes_text}
void main() {{
  group('{bug_name.replace("-", " ").title()} - Fix Verification', () {{
    test('Fix should resolve the main issue', () {{
      print('\\n═══════════════════════════════════════════════════════════════');
      print('✅ Fix Verification: Main Issue Resolved');
      print('═══════════════════════════════════════════════════════════════');
      print('');
      // Add verification logic here
      expect(true, isTrue, reason: 'Fix not yet verified');
    }});

    test('Fix should not introduce regressions', () {{
      // Verify existing functionality still works
      expect(true, isTrue, reason: 'Regression test not yet implemented');
    }});

    test('Fix should handle edge cases', () {{
      // Test edge cases with the fix
      expect(true, isTrue, reason: 'Edge case test not yet implemented');
    }});
  }});
}}
"""

    # Write test file
    with open(test_file, 'w', encoding='utf-8') as f:
        f.write(test_content)

    print(f"✅ Created verification test file: {{test_file.relative_to(project_root)}}")

    return test_file


def generate_fix_report(bug_name, description, root_cause, fixes, project_root=None):
    """
    Generate a fix report markdown file

    Args:
        bug_name: Name of the bug
        description: Bug description
        root_cause: Root cause analysis
        fixes: List of fix descriptions
        project_root: Path to Flutter project root (optional)
    """
    if project_root is None:
        project_root = Path.cwd()
    else:
        project_root = Path(project_root)

    # Create reports directory
    report_dir = project_root / "test" / "reports"
    report_dir.mkdir(parents=True, exist_ok=True)

    # Generate report file name
    report_file = report_dir / f"{bug_name}_fix_report.md"

    # Generate report content
    fixes_text = "\n".join([f"{i+1}. {fix}" for i, fix in enumerate(fixes)])

    report_content = f"""# {bug_name.replace("-", " ").title()} Bug Fix Report

## Bug Description

{description}

## Root Cause

{root_cause}

## Fixes Applied

{fixes_text}

## Testing

- [ ] Unit tests pass
- [ ] Widget tests pass
- [ ] Manual testing completed
- [ ] No regressions detected

## Files Modified

<!-- List all files that were modified to fix this bug -->

## Lessons Learned

<!-- Document what was learned from this bug fix -->

---

**Generated**: {os.popen('date /t').read().strip() if os.name == 'nt' else os.popen('date +%Y-%m-%d').read().strip()}
"""

    # Write report file
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report_content)

    print(f"✅ Created fix report: {{report_file.relative_to(project_root)}}")

    return report_file


def main():
    """CLI interface for the test generator"""
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python generate_flutter_tests.py bug <bug-name> <description>")
        print("  python generate_flutter_tests.py verify <bug-name> <fix1> <fix2> ...")
        print("  python generate_flutter_tests.py report <bug-name>")
        print("")
        print("Examples:")
        print('  python generate_flutter_tests.py bug blank-screen "Screen shows blank despite data loading"')
        print('  python generate_flutter_tests.py verify blank-screen "Added ref.watch()" "Fixed timing"')
        print("  python generate_flutter_tests.py report blank-screen")
        sys.exit(1)

    command = sys.argv[1]

    if command == "bug":
        if len(sys.argv) < 4:
            print("Error: bug command requires bug-name and description")
            sys.exit(1)

        bug_name = sys.argv[2].lower().replace(" ", "-")
        description = sys.argv[3]
        generate_bug_test(bug_name, description)

    elif command == "verify":
        if len(sys.argv) < 4:
            print("Error: verify command requires bug-name and at least one fix description")
            sys.exit(1)

        bug_name = sys.argv[2].lower().replace(" ", "-")
        fixes = sys.argv[3:]
        generate_fix_verification_test(bug_name, fixes)

    elif command == "report":
        if len(sys.argv) < 3:
            print("Error: report command requires bug-name")
            sys.exit(1)

        bug_name = sys.argv[2].lower().replace(" ", "-")
        print(f"\nGenerating fix report for: {bug_name}")
        description = input("Bug description: ")
        root_cause = input("Root cause: ")
        print("Enter fixes (one per line, empty line to finish):")
        fixes = []
        while True:
            fix = input(f"Fix {len(fixes)+1}: ")
            if not fix:
                break
            fixes.append(fix)

        generate_fix_report(bug_name, description, root_cause, fixes)

    else:
        print(f"Error: Unknown command '{command}'")
        print("Available commands: bug, verify, report")
        sys.exit(1)


if __name__ == "__main__":
    main()
