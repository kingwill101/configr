import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class ContainerBlock extends ActionBlock {
  @override
  String get blockType => 'container';

  String state = 'running';
  String image = '';
  String tag = 'latest';
  String containerName = '';
  String ports = '';
  String volumes = '';
  String env = '';
  String command = '';
  String restartPolicy = '';
  String network = '';
  String healthCheck = '';
  bool pull = false;
  bool existed = false;
  bool wasRunning = false;

  ContainerBlock();

  @override
  void resetState() {
    super.resetState();
    state = 'running';
    image = '';
    tag = 'latest';
    containerName = '';
    ports = '';
    volumes = '';
    env = '';
    command = '';
    restartPolicy = '';
    network = '';
    healthCheck = '';
    pull = false;
    existed = false;
    wasRunning = false;
  }

  @override
  Map<String, String> get additionalProperties => {
    if (state != 'running') 'state': state,
    if (image.isNotEmpty) 'image': image,
    if (tag != 'latest') 'tag': tag,
    if (containerName.isNotEmpty) 'container_name': containerName,
    if (ports.isNotEmpty) 'ports': ports,
    if (volumes.isNotEmpty) 'volumes': volumes,
    if (env.isNotEmpty) 'env': env,
    if (command.isNotEmpty) 'command': command,
    if (restartPolicy.isNotEmpty) 'restart_policy': restartPolicy,
    if (network.isNotEmpty) 'network': network,
    if (healthCheck.isNotEmpty) 'health_check': healthCheck,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {if (pull) 'pull': pull};

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    state = context.getString('state', state);
    image = context.getString('image', image);
    tag = context.getString('tag', tag);
    containerName = context.getString('container_name', containerName);
    ports = context.getString('ports', ports);
    volumes = context.getString('volumes', volumes);
    env = context.getString('env', env);
    command = context.getString('command', command);
    restartPolicy = context.getString('restart_policy', restartPolicy);
    network = context.getString('network', network);
    healthCheck = context.getString('health_check', healthCheck);
    pull = context.getBool('pull', pull);
  }

  @override
  String dryRunSummary() {
    if (image.isNotEmpty) {
      return '$blockType: $state $image:$tag'
          '${containerName.isNotEmpty ? ' ($containerName)' : ''}';
    }
    return super.dryRunSummary();
  }

  Future<String?> _execDocker(List<String> args) async {
    try {
      final result = await runCommand('docker', args, checkExitCode: false);
      final exitCode = result.exitCode;
      if (exitCode == 0) {
        return result.stdout?.toString().trim();
      }
      logger.debug('docker ${args.first} exited $exitCode: ${result.stderr}');
      return null;
    } catch (e) {
      logger.error('docker command failed: $e');
      return null;
    }
  }

  Future<bool> _containerExists() async {
    final output = await _execDocker([
      'ps',
      '-a',
      '--filter',
      'name=^/$containerName\$',
      '--format',
      '{{.Names}}',
    ]);
    return output != null && output.contains(containerName);
  }

  Future<bool> _containerRunning() async {
    final output = await _execDocker([
      'ps',
      '--filter',
      'name=^/$containerName\$',
      '--filter',
      'status=running',
      '--format',
      '{{.Names}}',
    ]);
    return output != null && output.contains(containerName);
  }

  Future<void> _pullImage() async {
    emitEvent(
      StatusUpdateEvent(
        moduleId: id,
        level: StatusEvent.info,
        message: 'Pulling image $image:$tag',
      ),
    );
    await runCommand('docker', ['pull', '$image:$tag'], checkExitCode: false);
  }

  Future<void> _startContainer() async {
    final imageRef = '$image:$tag';
    final cmdArgs = <String>['run', '-d', '--name', containerName];
    if (restartPolicy.isNotEmpty) {
      cmdArgs.addAll(['--restart', restartPolicy]);
    }
    if (network.isNotEmpty) {
      cmdArgs.addAll(['--network', network]);
    }
    if (ports.isNotEmpty) {
      for (final p in ports.split(',')) {
        cmdArgs.addAll(['-p', p.trim()]);
      }
    }
    if (volumes.isNotEmpty) {
      for (final v in volumes.split(',')) {
        cmdArgs.addAll(['-v', v.trim()]);
      }
    }
    if (env.isNotEmpty) {
      for (final e in env.split(',')) {
        cmdArgs.addAll(['-e', e.trim()]);
      }
    }
    cmdArgs.add(imageRef);
    if (command.isNotEmpty) {
      cmdArgs.addAll(command.split(' '));
    }

    emitEvent(
      StatusUpdateEvent(
        moduleId: id,
        level: StatusEvent.info,
        message: 'Starting container $containerName',
      ),
    );
    await runCommand('docker', cmdArgs, checkExitCode: false);
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Managing container $containerName ($image:$tag)',
      ),
    );

    existed = await _containerExists();
    wasRunning = existed ? await _containerRunning() : false;

    if (state == 'absent') {
      if (existed) {
        if (wasRunning) {
          emitEvent(
            StatusUpdateEvent(
              moduleId: id,
              level: StatusEvent.info,
              message: 'Stopping container $containerName',
            ),
          );
          await runCommand('docker', [
            'stop',
            containerName,
          ], checkExitCode: false);
        }
        emitEvent(
          StatusUpdateEvent(
            moduleId: id,
            level: StatusEvent.info,
            message: 'Removing container $containerName',
          ),
        );
        await runCommand('docker', ['rm', containerName], checkExitCode: false);
      } else {
        logger.info(
          'Container $containerName does not exist — nothing to remove.',
        );
      }
      status = 'completed';
      return;
    }

    if (pull) {
      await _pullImage();
    }

    if (state == 'running' || state == 'started') {
      if (existed) {
        if (!wasRunning) {
          emitEvent(
            StatusUpdateEvent(
              moduleId: id,
              level: StatusEvent.info,
              message: 'Starting existing container $containerName',
            ),
          );
          await runCommand('docker', [
            'start',
            containerName,
          ], checkExitCode: false);
        } else {
          logger.info('Container $containerName is already running.');
        }
      } else {
        await _startContainer();
      }
    } else if (state == 'stopped') {
      if (existed && wasRunning) {
        emitEvent(
          StatusUpdateEvent(
            moduleId: id,
            level: StatusEvent.info,
            message: 'Stopping container $containerName',
          ),
        );
        await runCommand('docker', [
          'stop',
          containerName,
        ], checkExitCode: false);
      } else if (!existed) {
        logger.info('Container $containerName does not exist — cannot stop.');
      } else {
        logger.info('Container $containerName is already stopped.');
      }
    } else if (state == 'restarted') {
      if (existed) {
        emitEvent(
          StatusUpdateEvent(
            moduleId: id,
            level: StatusEvent.info,
            message: 'Restarting container $containerName',
          ),
        );
        await runCommand('docker', [
          'restart',
          containerName,
        ], checkExitCode: false);
      } else {
        await _startContainer();
      }
    }

    if (healthCheck.isNotEmpty &&
        (state == 'running' || state == 'started' || state == 'restarted')) {
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          level: StatusEvent.info,
          message: 'Running health check: $healthCheck',
        ),
      );
      final result = await runCommand('docker', [
        'exec',
        containerName,
        ...healthCheck.split(' '),
      ], checkExitCode: false);
      if (result.exitCode != 0) {
        logger.warning('Health check failed for container $containerName');
      }
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Rolling back container operation on $containerName',
      ),
    );

    if (state == 'absent') {
      if (!existed) return;
      await runCommand('docker', [
        'start',
        containerName,
      ], checkExitCode: false);
      if (!wasRunning) {
        await runCommand('docker', [
          'stop',
          containerName,
        ], checkExitCode: false);
      }
    } else if (state == 'running' || state == 'started') {
      if (!existed) {
        await runCommand('docker', [
          'rm',
          '-f',
          containerName,
        ], checkExitCode: false);
      } else if (!wasRunning) {
        await runCommand('docker', [
          'stop',
          containerName,
        ], checkExitCode: false);
      }
    } else if (state == 'stopped') {
      if (wasRunning) {
        await runCommand('docker', [
          'start',
          containerName,
        ], checkExitCode: false);
      }
    } else if (state == 'restarted') {
      // no-op — container is in the restarted state
    }

    emitEvent(
      CompletedEvent(
        moduleId: id,
        message: 'Container rollback completed for $containerName',
      ),
    );
  }
}
