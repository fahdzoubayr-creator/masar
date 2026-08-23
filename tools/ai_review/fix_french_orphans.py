#!/usr/bin/env python3
"""Fix orphaned multi-line options in french_didactics files.

When clean_bank_files.py collapsed 5-option questions to 4-option inline,
it left the old multi-line options dangling. Fix: clean up the corrupted
options line and remove the orphaned lines.
"""
import re

def fix_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    result = []
    i = 0
    fixed_count = 0
    
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        if 'options:' in stripped and stripped.startswith('options:'):
            # Check for corruption pattern: the line ends with something like
            # ], et [b]',  or ].",  after a proper 4-element options array
            # 
            # Strategy: find the options array by searching for the pattern:
            #   options: ['...'], '...'], '...'], '...']<garbage>
            # A valid 4-option line should have exactly 4 single-quoted strings
            # followed by ],  or ],
            #
            # The corruption always has extra characters after the array close.
            # Simple check: does the stripped line NOT end with either:
            #   ],  or ],  followed by only whitespace or //comment?
            
            # Remove trailing whitespace
            test = stripped.rstrip()
            
            # Check if line ends properly (], or ],\n or ], // comment)
            if re.search(r"\]\s*,\s*$", test):
                # Looks clean - valid options line
                pass
            elif re.search(r"\]\s*,\s*//", test):
                # Has a comment after - also valid
                pass
            else:
                # Corrupted! Find the proper end of the options array
                # The options array should be: ['...', '...', '...', '...']
                # Find the position after the 4th closing quote + bracket
                # Strategy: find the LAST ']', followed by a comma
                # Since the corruption is always after ], we can find
                # the first ], (closing the array) and truncate there
                
                # Count single-quoted strings to find the array boundary
                in_single = False
                array_end = -1
                for ci, ch in enumerate(test):
                    if ch == "'" and (ci == 0 or test[ci-1] != '\\'):
                        in_single = False if in_single else True
                    elif ch == ']' and not in_single:
                        # Found a ] outside of a string - this should be the array close
                        array_end = ci
                        break
                
                if array_end > 0:
                    indent = line[:len(line) - len(line.lstrip())]
                    fixed_line = test[:array_end+1] + ','
                    result.append(indent + fixed_line + '\n')
                    
                    # Skip orphaned lines until we find the old closing ],
                    i += 1
                    while i < len(lines):
                        s = lines[i].strip()
                        if s in ('],', '],'):
                            # Orphaned old closing bracket - skip it
                            i += 1
                            break
                        elif any(s.startswith(p) for p in ['correctIndex:', 'explanation:', '//', 'Question(', 'subject:']):
                            # Past the orphaned block
                            break
                        i += 1
                    
                    fixed_count += 1
                    continue
        
        result.append(line)
        i += 1
    
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(result)
    
    return fixed_count

files = [
    r'lib\core\data\french_didactics_bank_4_data.dart',
    r'lib\core\data\french_didactics_bank_all.dart',
]

for fp in files:
    count = fix_file(fp)
    print(f'{fp}: fixed {count} orphaned blocks')
