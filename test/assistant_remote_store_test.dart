import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/features/ai_assistant/data/assistant_conversation_store.dart';
import 'package:nikara_app/features/ai_assistant/domain/models/assistant_models.dart';
import 'support/account_data_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AccountDataServer server;
  late SupabaseClient client;
  late AssistantConversationStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = AccountDataServer();
    client = server.newClient();
    await client.auth.recoverSession(accountSession(userA));
    store = AssistantConversationStore.forTesting(client);
  });
  tearDown(() => client.dispose());
  test(
    'another device retrieves the conversation and the account filter isolates it',
    () async {
      final id = await store.save(
        messages: [AssistantMessage.user('Viajar a Granada')],
      );
      final device = server.newClient();
      await device.auth.recoverSession(accountSession(userA));
      final remoteStore = AssistantConversationStore.forTesting(device);
      final saved = (await remoteStore.load()).single;
      expect(saved.id, id);
      expect(saved.messages.single.text, 'Viajar a Granada');
      await device.auth.recoverSession(accountSession(userB));
      expect(await remoteStore.load(), isEmpty);
      await store.delete(id);
      expect(await store.load(), isEmpty);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'assistant_conversations_v1',
        ),
        isFalse,
      );
      await device.dispose();
    },
  );
  test('a failed save reports failure without a local fallback', () async {
    server.failWrites = true;
    await expectLater(
      store.save(messages: [AssistantMessage.user('Hola')]),
      throwsA(isA<PostgrestException>()),
    );
    expect(server.conversations, isEmpty);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
  test('a guest conversation is never persisted', () async {
    await client.auth.signOut(scope: SignOutScope.local);
    expect(await store.save(messages: [AssistantMessage.user('Hola')]), '');
    expect(await store.load(), isEmpty);
    expect(server.conversations, isEmpty);
  });
}
