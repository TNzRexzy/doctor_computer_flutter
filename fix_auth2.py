path = 'D:/SMS 5/Mobile/Project/doctor_computer_flutter_fix/lib/providers/auth_provider.dart'

with open(path, 'r') as f:
    content = f.read()

# Fix error and data access - cast to dynamic
content = content.replace('if (authRes.error != null) {', 'if ((authRes as dynamic).error != null) {')
content = content.replace('if (authRes.data?[\'user\'][\'id\']) == null', 'if (((authRes as dynamic)?.data?[\'user\'][\'id\']) == null)')

# Fix the data field access
content = content.replace('final userId = authRes.data?[\"user\"][\"id\"];', 'final userId = ((authRes as dynamic)?.data?[\'user\'][\'id\'])')

# Fix error and data in profile insert
content = content.replace('if ((profileRes as dynamic).error != null) {', 'if (((profileRes as dynamic)?.error) != null) {')

# Fix error and data in profile fetch
content = content.replace('if ((fetchRes as dynamic).error != null) {', 'if (((fetchRes as dynamic)?.error) != null) {')

with open(path, 'w') as f:
    f.write(content)
print('Done')
