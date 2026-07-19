import 'ssh_command_service.dart';

/// Builds and executes docker CLI commands via SSH.
/// Returns raw SshResult — parsing is done by providers/models.
class DockerService {
  final SshCommandService _ssh;

  DockerService(this._ssh);

  SshCommandService get ssh => _ssh;

  // ─── Container ───

  /// docker ps --all --format '{{json .}}'
  Future<SshResult> listContainers({bool all = true}) {
    final flag = all ? '--all' : '';
    return _ssh.execute("docker ps $flag --format '{{json .}}'");
  }

  /// docker ps --filter "name=<name>" --format '{{json .}}'
  Future<SshResult> findContainer(String name) {
    return _ssh.execute(
      "docker ps --all --filter 'name=$name' --format '{{json .}}'",
    );
  }

  /// docker start|stop|restart|pause|unpause|kill <name>
  Future<SshResult> operate(String name, String op) {
    return _ssh.execute('docker $op $name');
  }

  /// docker rm -f <name>
  Future<SshResult> remove(String name, {bool force = true}) {
    final f = force ? '-f' : '';
    return _ssh.execute('docker rm $f $name');
  }

  /// docker rename <old> <new>
  Future<SshResult> rename(String oldName, String newName) {
    return _ssh.execute('docker rename $oldName $newName');
  }

  /// docker stats --no-stream --format '{{json .}}' <name>
  Future<SshResult> stats(String name) {
    return _ssh.execute("docker stats --no-stream --format '{{json .}}' $name");
  }

  /// docker inspect <name>
  Future<SshResult> inspect(String name) {
    return _ssh.execute('docker inspect $name');
  }

  /// docker update ...
  Future<SshResult> updateContainer(String name, Map<String, String> opts) {
    final args = opts.entries.map((e) => '--${e.key}=${e.value}').join(' ');
    return _ssh.execute('docker update $args $name');
  }

  /// docker logs --tail <n> [-f] <name>
  Stream<String> logs(String name, {int tail = 200, bool follow = false}) {
    final f = follow ? '-f' : '';
    return _ssh.stream('docker logs $f --tail $tail $name');
  }

  /// docker logs --tail <n> (non-streaming)
  Future<SshResult> logsOnce(String name, {int tail = 200}) {
    return _ssh.execute('docker logs --tail $tail $name');
  }

  // ─── Image ───

  /// docker images --format '{{json .}}'
  Future<SshResult> listImages() {
    return _ssh.execute("docker images --format '{{json .}}'");
  }

  /// docker pull <image>
  /// Uses streaming to show progress
  Stream<String> pull(String image) {
    return _ssh.stream('docker pull $image');
  }

  /// docker pull <image> (non-streaming, returns when done)
  Future<SshResult> pullSync(String image) {
    return _ssh.execute('docker pull $image', timeout: const Duration(minutes: 10));
  }

  /// docker rmi [-f] <id>
  Future<SshResult> removeImage(String id, {bool force = false}) {
    final f = force ? '-f' : '';
    return _ssh.execute('docker rmi $f $id');
  }

  /// docker image prune [-a] -f
  Future<SshResult> pruneImages({bool all = false}) {
    final a = all ? '-a' : '';
    return _ssh.execute('docker image prune $a -f');
  }

  /// Check if newer version of image exists
  /// docker manifest inspect <image> (remote) vs docker image inspect <image> (local)
  Future<SshResult> checkImageUpdate(String image) {
    return _ssh.execute('docker manifest inspect $image 2>/dev/null || echo "{}"');
  }

  /// docker image inspect <image>
  Future<SshResult> inspectImage(String image) {
    return _ssh.execute('docker image inspect $image');
  }

  // ─── Compose ───

  /// Detect available compose command: docker compose or docker-compose
  Future<String> detectComposeCmd() async {
    final r = await _ssh.execute('docker compose version 2>/dev/null');
    if (r.isSuccess) return 'docker compose';
    final r2 = await _ssh.execute('docker-compose --version 2>/dev/null');
    if (r2.isSuccess) return 'docker-compose';
    return 'docker compose'; // default
  }

  /// docker compose ls --format json
  Future<SshResult> listComposes() {
    return _ssh.execute('docker compose ls --format json 2>/dev/null || echo "[]"');
  }

  /// docker compose -f <file> ps --format json
  Future<SshResult> composePs(String workdir, {String? file}) {
    final f = file ?? 'docker-compose.yml';
    return _ssh.execute(
      'cd "$workdir" && docker compose -f "$f" ps --format json 2>/dev/null || echo "[]"',
    );
  }

  /// docker compose -f <file> up -d / down / stop / restart / pull
  Future<SshResult> composeOp(
    String workdir,
    String op, {
    String? file,
  }) {
    final f = file ?? 'docker-compose.yml';
    final cmd = switch (op) {
      'up' => 'up -d',
      'down' => 'down',
      'stop' => 'stop',
      'restart' => 'restart',
      'pull' => 'pull',
      _ => op,
    };
    return _ssh.execute('cd "$workdir" && docker compose -f "$f" $cmd');
  }

  /// docker compose -f <file> logs [-f] --tail <n>
  Stream<String> composeLogs(
    String workdir, {
    String? file,
    int tail = 200,
    bool follow = false,
  }) {
    final fFlag = follow ? '-f' : '';
    final cf = file ?? 'docker-compose.yml';
    return _ssh.stream(
      'cd "$workdir" && docker compose -f "$cf" logs $fFlag --tail $tail',
    );
  }

  /// Find compose files on the server
  Future<SshResult> findComposeFiles() {
    return _ssh.execute(
      r'''find / -maxdepth 4 -name "docker-compose.yml" -o -name "compose.yaml" 2>/dev/null | head -50''',
    );
  }

  // ─── Registry Mirrors ───

  /// Read /etc/docker/daemon.json
  Future<SshResult> readDaemonJson() {
    return _ssh.execute('cat /etc/docker/daemon.json 2>/dev/null || echo "{}"');
  }

  /// Write /etc/docker/daemon.json (needs sudo)
  Future<SshResult> writeDaemonJson(String content) {
    // Escape single quotes: ' → '\''
    final escaped = content.replaceAll("'", "'\\''");
    return _ssh.execute(
      "echo '$escaped' | sudo tee /etc/docker/daemon.json > /dev/null",
    );
  }

  /// systemctl reload docker
  Future<SshResult> reloadDaemon() {
    return _ssh.execute('sudo systemctl reload docker 2>/dev/null || sudo systemctl restart docker');
  }

  // ─── Docker Daemon ───

  /// docker info --format '{{json .}}'
  Future<SshResult> dockerInfo() {
    return _ssh.execute("docker info --format '{{json .}}' 2>/dev/null || echo '{}'");
  }

  /// systemctl status docker
  Future<SshResult> daemonStatus() {
    return _ssh.execute('systemctl status docker --no-pager 2>/dev/null || echo "inactive"');
  }

  /// systemctl start|stop|restart docker
  Future<SshResult> daemonOp(String op) {
    return _ssh.execute('sudo systemctl $op docker');
  }

  /// Check if docker is available
  Future<bool> isDockerAvailable() async {
    final r = await _ssh.execute('docker --version 2>/dev/null');
    return r.isSuccess;
  }
}
