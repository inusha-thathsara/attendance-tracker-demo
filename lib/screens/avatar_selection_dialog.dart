import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class AvatarSelectionDialog extends StatelessWidget {
  const AvatarSelectionDialog({super.key});

  final List<String> _avatars = const [
    'avatar_1.png',
    'avatar_2.png',
    'avatar_3.png',
    'avatar_4.png',
    'avatar_5.png',
    'avatar_6.png',
    'avatar_7.png',
    'avatar_8.png',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Profile Picture'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _avatars.length,
          itemBuilder: (context, index) {
            final avatar = _avatars[index];
            return GestureDetector(
              onTap: () {
                Provider.of<UserProvider>(context, listen: false).setAvatarKey(avatar);
                Navigator.pop(context);
              },
              child: CircleAvatar(
                backgroundImage: AssetImage('assets/avatars/$avatar'),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
