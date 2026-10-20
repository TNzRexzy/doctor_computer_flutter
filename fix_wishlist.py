lines = open('lib/providers/wishlist_provider.dart', encoding='utf-8').read().split('\n')
for i, line in enumerate(lines):
    # Fix line 138: 'user_id': _userId as Object?  ->  Remove this line (it was a previous wrong fix)
    if i == 137 and "'user_id': _userId as Object?" in line:
        lines[i] = "'user_id': _userId!"
        print('Fixed line 138')
        break
open('lib/providers/wishlist_provider.dart', 'w', encoding='utf-8').write('\n'.join(lines))
print('Done')
