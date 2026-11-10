import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../desktop/host_identity.dart';
import '../desktop/platform_kind.dart';
import '../game/content.dart';
import '../online/client.dart';
import '../platform.dart';
import 'race_screen.dart';
import 'widgets.dart';

class OnlineScreen extends StatefulWidget {
  final GameStore store;
  final List<TrackSpec> tracks;
  final List<ArenaSpec> arenas;
  final VoidCallback onBack;
  final OnlineClient? client;
  const OnlineScreen({
    super.key,
    required this.store,
    required this.tracks,
    required this.arenas,
    required this.onBack,
    this.client,
  });
  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  late final OnlineClient client;
  late final TextEditingController username;
  final code = TextEditingController();
  StreamSubscription<void>? subscription;
  String kind = 'race';
  bool localNetwork = false;
  late String map;
  int car = 0;
  @override
  void initState() {
    super.initState();
    client =
        widget.client ??
        OnlineClient(
          tracks: widget.tracks,
          arenas: widget.arenas,
          createHostIdentity: () async {
            if (isWindowsDesktop) return DesktopHost.identity();
            const channel = MethodChannel('com.hirumisu.carwece/host');
            final identity = await channel.invokeMapMethod<String, String>(
              'identity',
            );
            if (identity == null)
              throw StateError('Não foi possível preparar a sala.');
            return identity;
          },
          hostService: (active) async {
            if (isWindowsDesktop) return DesktopHost.service(active);
            await const MethodChannel(
              'com.hirumisu.carwece/host',
            ).invokeMethod<void>(active ? 'start' : 'stop');
          },
        );
    username = TextEditingController(
      text: widget.store.settings.onlineUsername,
    );
    map = widget.tracks.first.id;
    car = widget.store.selectedCar;
    subscription = client.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(subscription?.cancel());
    if (widget.client == null) client.dispose();
    username.dispose();
    code.dispose();
    super.dispose();
  }

  Widget card(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xff344158)),
    ),
    child: child,
  );
  InputDecoration field(String label, {Widget? suffix}) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    isDense: true,
    suffixIcon: suffix,
  );
  bool get owned =>
      (client.profile?['owned'] as List? ?? []).contains(cars[car].id);
  Future<void> friendAction(bool create) async {
    FocusScope.of(context).unfocus();
    widget.store.settings.onlineUsername = username.text.trim();
    widget.store.changed();
    if (create) {
      await client.createWithFriends(
        username: username.text,
        garage: widget.store.ownedCars.toList(),
        kind: kind,
        map: map,
        car: car,
        localNetwork: localNetwork,
      );
    } else {
      await client.joinWithFriends(
        username: username.text,
        garage: widget.store.ownedCars.toList(),
        invitation: code.text,
        car: car,
      );
    }
  }

  Widget get loginCard => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('JOGUE COM SEUS AMIGOS', style: display(28)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('friend-username'),
              controller: username,
              maxLength: 20,
              enabled: !client.busy,
              autocorrect: false,
              decoration: field('Seu nome de piloto'),
              textInputAction: TextInputAction.done,
            ),
            Text(
              'Sem senha ou cadastro. Seu nome fica salvo neste aparelho.',
              style: body(12, color: muted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: [
                for (final local in [false, true])
                  ChoiceChip(
                    key: ValueKey(local ? 'friend-lan' : 'friend-internet'),
                    label: Text(local ? 'MESMO WI-FI' : 'INTERNET'),
                    selected: localNetwork == local,
                    onSelected: client.busy
                        ? null
                        : (_) => setState(() => localNetwork = local),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                for (final k in ['race', 'battle'])
                  ChoiceChip(
                    label: Text(k == 'race' ? 'CORRIDA' : 'BATALHA'),
                    selected: kind == k,
                    onSelected: client.busy
                        ? null
                        : (_) => setState(() {
                            kind = k;
                            map = k == 'race'
                                ? widget.tracks.first.id
                                : widget.arenas.first.track.id;
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('friend-map-$kind'),
              initialValue: map,
              isExpanded: true,
              decoration: field('Pista da sua sala'),
              items: [
                for (final t
                    in kind == 'race'
                        ? widget.tracks
                        : widget.arenas.map((a) => a.track))
                  DropdownMenuItem(
                    value: t.id,
                    child: Text(t.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: client.busy
                  ? null
                  : (v) {
                      if (v != null) setState(() => map = v);
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const ValueKey('friend-car'),
              initialValue: car,
              isExpanded: true,
              decoration: field('Seu carro'),
              items: [
                for (var i = 0; i < cars.length; i++)
                  if (widget.store.ownedCars.contains(cars[i].id))
                    DropdownMenuItem(value: i, child: Text(cars[i].name)),
              ],
              onChanged: client.busy
                  ? null
                  : (v) {
                      if (v != null) setState(() => car = v);
                    },
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('friend-create'),
              onPressed: client.busy
                  ? null
                  : () => unawaited(friendAction(true)),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('CRIAR MINHA SALA'),
            ),
            const SizedBox(height: 10),
            Text(
              localNetwork
                  ? 'Todos precisam estar no mesmo Wi-Fi ou ponto de acesso. Esta opção não usa retransmissor nem precisa de internet.'
                  : 'Para amigos em outras casas. A conexão tenta caminhos alternativos automaticamente e testa a sala antes de liberar o convite. Aguarde a criação terminar. Cada sala gratuita dura até 60 minutos.',
              style: body(13, color: muted),
            ),
            const Divider(height: 30),
            TextField(
              key: const ValueKey('friend-invite'),
              controller: code,
              autocorrect: false,
              enableSuggestions: false,
              enabled: !client.busy,
              minLines: 1,
              maxLines: 3,
              decoration: field('Cole o convite do seu amigo'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('friend-join'),
              onPressed: client.busy
                  ? null
                  : () => unawaited(friendAction(false)),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('ENTRAR NA SALA DO AMIGO'),
            ),
            const SizedBox(height: 12),
            Text(
              'Até 6 jogadores. O anfitrião precisa manter o jogo aberto e a rede conectada. O convite identifica se a sala é da internet ou do mesmo Wi-Fi.',
              style: body(12, color: cyan),
            ),
          ],
        ),
      ),
    ],
  );

  Widget get garage => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('GARAGEM ONLINE', style: display(25)),
        const SizedBox(height: 10),
        Text(
          client.friendMode
              ? 'SEUS CARROS • SESSÃO ENTRE AMIGOS'
              : '${client.profile?['coins'] ?? 0} MOEDAS • ${client.profile?['stars'] ?? 0} ★ • ${client.profile?['wins'] ?? 0} VITÓRIAS',
          style: body(13, color: cyan),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          key: const ValueKey('online-car'),
          initialValue: car,
          isExpanded: true,
          decoration: field('Carro'),
          items: [
            for (var i = 0; i < cars.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(
                  '${cars[i].name}${(client.profile?['owned'] as List? ?? []).contains(cars[i].id) ? '' : ' • BLOQUEADO'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: client.room != null && client.room!['phase'] != 'lobby'
              ? null
              : (i) {
                  if (i == null) return;
                  setState(() => car = i);
                  if (owned && client.room != null)
                    client.send({'type': 'car', 'car': car});
                },
        ),
        const SizedBox(height: 8),
        Text(
          '1º: 1.000 • 2º: 500 • 3º: 250 moedas',
          style: body(12, color: muted),
        ),
      ],
    ),
  );
  Widget get roomCard {
    final r = client.room!;
    var mapName = '${r['map']}';
    for (final t in [...widget.tracks, ...widget.arenas.map((a) => a.track)])
      if (t.id == r['map']) mapName = t.name;
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('SALA ${r['code']}', style: display(34, color: orange)),
          Text(
            client.friendInvite?.isLocal == true
                ? 'MESMO WI-FI • todos na mesma rede'
                : 'INTERNET • túnel seguro • até 60 minutos por sala',
            style: body(12, color: cyan),
          ),
          Text(
            '${r['kind'] == 'battle' ? 'BATALHA' : 'CORRIDA'} • $mapName',
            style: body(14, color: cyan),
          ),
          TextButton.icon(
            onPressed: () => unawaited(
              Clipboard.setData(
                ClipboardData(text: client.shareCode ?? r['code']),
              ),
            ),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('COPIAR CONVITE PARA OS AMIGOS'),
          ),
          if (client.phoneHost != null)
            Text(
              'Seu celular está hospedando. Ao sair ou fechar o jogo, a sala será encerrada para todos.',
              style: body(12, color: muted),
            ),
          const Divider(),
          for (final p in r['players'])
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.circle,
                size: 12,
                color: p['connected'] == true ? const Color(0xff97da77) : muted,
              ),
              title: Text(
                '${p['name']}${r['host'] == '${p['name']}'.toLowerCase() ? ' • ANFITRIÃO' : ''}',
              ),
              subtitle: Text(cars[p['car']].name),
            ),
          const SizedBox(height: 12),
          if (client.host)
            FilledButton(
              onPressed: client.connected && (r['players'] as List).length >= 2
                  ? () => client.send({'type': 'start'})
                  : null,
              child: const Text('INICIAR PARTIDA'),
            )
          else
            Text(
              'Aguarde o anfitrião iniciar. Todos carregam a pista antes da largada.',
              style: body(13, color: muted),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: client.leaveRoom,
            child: const Text('SAIR DA SALA'),
          ),
        ],
      ),
    );
  }

  Widget get resultCard => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${client.result!.position}º LUGAR',
          style: display(42, color: orange),
        ),
        Text(
          client.friendMode
              ? 'PARTIDA ENTRE AMIGOS • +${client.result!.coins} MOEDAS NESTA SESSÃO'
              : '+${client.result!.coins} MOEDAS NA CONTA ONLINE',
          style: body(15, color: cyan),
        ),
        const SizedBox(height: 14),
        for (final s in client.result!.standings)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text('${s.position}', style: display(24)),
            title: Text(s.name),
            subtitle: Text(s.car.name),
          ),
        if (client.host)
          FilledButton(
            onPressed: client.connected
                ? () => client.send({'type': 'lobby'})
                : null,
            child: const Text('PREPARAR PRÓXIMA PARTIDA'),
          ),
        if (!client.host)
          Text(
            'Aguarde o anfitrião preparar a próxima partida.',
            style: body(13, color: muted),
          ),
        OutlinedButton(
          onPressed: client.leaveRoom,
          child: const Text('SAIR DA SALA'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (client.match != null && client.result == null) {
      return Stack(
        children: [
          RaceScreen(
            key: ValueKey(client.match),
            race: client.match!,
            store: widget.store,
            onFinish: (_) {
              if (mounted) setState(() {});
            },
            onExit: client.leaveRoom,
          ),
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    client.error.isNotEmpty
                        ? client.error
                        : client.connected
                        ? '${client.friendInvite?.isLocal == true ? 'WI-FI' : 'ONLINE'} • ${client.pingMs} ms${client.room?['phase'] == 'loading' ? ' • AGUARDANDO CARREGAMENTO' : ''}'
                        : client.status,
                    style: body(10, color: client.connected ? cyan : orange),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          client.leaveRoom();
          widget.onBack();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      tooltip: 'Voltar',
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text('MULTIPLAYER • AMIGOS', style: display(26)),
                    ),
                    if (client.profile != null)
                      TextButton(
                        onPressed: () => unawaited(client.signOut()),
                        child: const Text('DESCONECTAR'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    client.profile == null
                        ? client.status
                        : '${client.name} • ${client.status}',
                    style: body(12, color: cyan),
                  ),
                ),
              ),
              if (client.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 5,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(client.error, style: body(13, color: orange)),
                  ),
                ),
              if (client.busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, size) {
                    final left = client.profile == null
                        ? loginCard
                        : client.result != null
                        ? resultCard
                        : client.room != null
                        ? roomCard
                        : loginCard;
                    final right = client.profile == null
                        ? card(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SEUS AMIGOS. SUAS PISTAS.',
                                  style: display(28, color: orange),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  '${widget.tracks.length} circuitos • ${widget.arenas.length} arenas • até 6 jogadores',
                                  style: body(15),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Corridas com colisões e poderes. Batalhas com vida, armas coletadas no mapa e munição limitada.',
                                  style: body(14, color: muted),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Ao abrir o pause, a partida online continua e seu carro freia. Uma desconexão permite até 20 segundos para retornar.',
                                  style: body(13, color: muted),
                                ),
                              ],
                            ),
                          )
                        : Column(children: [garage]);
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: size.maxWidth >= 860
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: left),
                                    const SizedBox(width: 18),
                                    Expanded(child: right),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    left,
                                    const SizedBox(height: 16),
                                    right,
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
