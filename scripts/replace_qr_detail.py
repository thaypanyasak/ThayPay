with open('lib/src/ui/wallet_page.dart', encoding='utf-8') as f:
    content = f.read()

start = content.find('class _QrDetailPage extends StatelessWidget {')
end = content.find('\n// ---------------------------------------------------------------------------\n// Add / Edit form sheet')

new_class = open('scripts/qr_detail_class.txt', encoding='utf-8').read()
new_content = content[:start] + new_class + content[end:]

with open('lib/src/ui/wallet_page.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)
print('Done, new length:', len(new_content))
