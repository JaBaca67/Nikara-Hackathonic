/// Política y cupos calculados por el servidor para la sesión actual.
class EcoMomentState {
  const EcoMomentState({
    required this.enabled,
    required this.canManage,
    required this.canPost,
    this.maxMessages,
    this.maxAccounts,
    this.maxPerAccount,
    this.messageCount = 0,
    this.accountCount = 0,
    this.blockedReason,
  });

  final bool enabled;
  final bool canManage;
  final bool canPost;
  final int? maxMessages;
  final int? maxAccounts;
  final int? maxPerAccount;
  final int messageCount;
  final int accountCount;
  final String? blockedReason;

  factory EcoMomentState.fromJson(Map<String, dynamic> row) => EcoMomentState(
    enabled: row['enabled'] == true,
    canManage: row['can_manage'] == true,
    canPost: row['can_post'] == true,
    maxMessages: (row['max_messages'] as num?)?.toInt(),
    maxAccounts: (row['max_accounts'] as num?)?.toInt(),
    maxPerAccount: (row['max_per_account'] as num?)?.toInt(),
    messageCount: (row['message_count'] as num?)?.toInt() ?? 0,
    accountCount: (row['account_count'] as num?)?.toInt() ?? 0,
    blockedReason: row['blocked_reason'] as String?,
  );
}
