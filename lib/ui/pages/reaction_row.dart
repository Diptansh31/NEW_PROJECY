import 'package:flutter/material.dart';

typedef ReactionToggle = Future<void> Function(String emoji);

/// WhatsApp-style reaction badge that appears at the bottom of a message bubble.
/// Compact pill with emoji(s) and count.
class ReactionRow extends StatelessWidget {
  const ReactionRow({
    super.key,
    required this.reactions,
    required this.myUid,
    required this.onToggle,
    this.isMe = false,
  });

  final Map<String, List<String>> reactions;
  final String myUid;
  final ReactionToggle onToggle;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Sort by count (descending)
    final entries = reactions.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // Total reaction count
    final totalCount = entries.fold<int>(0, (sum, e) => sum + e.value.length);
    
    // Check if current user reacted
    final iReacted = entries.any((e) => e.value.contains(myUid));

    return GestureDetector(
      onTap: () => _showReactionDetails(context, entries, theme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: isDark 
              ? const Color(0xFF1F2C34) // WhatsApp dark mode reaction bg
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: iReacted 
                ? theme.colorScheme.primary.withValues(alpha: 0.6)
                : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.15)),
            width: iReacted ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show emojis (up to 3)
            for (int i = 0; i < entries.length && i < 3; i++)
              Text(
                entries[i].key,
                style: const TextStyle(fontSize: 13),
              ),
            // Show count only when more than 1 reaction
            if (totalCount > 1) ...[
              const SizedBox(width: 3),
              Text(
                totalCount.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReactionDetails(BuildContext context, List<MapEntry<String, List<String>>> entries, ThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Emoji tabs row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // All tab
                    _ReactionTab(
                      emoji: 'All',
                      count: entries.fold<int>(0, (sum, e) => sum + e.value.length),
                      isSelected: true,
                      theme: theme,
                    ),
                    const SizedBox(width: 16),
                    // Individual emoji tabs
                    for (final e in entries.take(4)) ...[
                      _ReactionTab(
                        emoji: e.key,
                        count: e.value.length,
                        isSelected: false,
                        theme: theme,
                      ),
                      const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              // Reaction list
              ...entries.map((e) {
                final iMine = e.value.contains(myUid);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(e.key, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  title: Text(
                    iMine ? 'You' : '${e.value.length} ${e.value.length == 1 ? 'person' : 'people'}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  subtitle: iMine ? const Text('Tap to remove') : null,
                  onTap: iMine
                      ? () {
                          Navigator.of(ctx).pop();
                          onToggle(e.key);
                        }
                      : null,
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _ReactionTab extends StatelessWidget {
  const _ReactionTab({
    required this.emoji,
    required this.count,
    required this.isSelected,
    required this.theme,
  });

  final String emoji;
  final int count;
  final bool isSelected;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected 
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: TextStyle(
              fontSize: emoji == 'All' ? 14 : 18,
              fontWeight: emoji == 'All' ? FontWeight.w600 : FontWeight.normal,
              color: emoji == 'All' ? theme.colorScheme.onSurface : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
