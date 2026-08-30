// lib/services/module_status/soleux_json_fetcher.dart
//
// Renders Soleux JSON protocol responses onto a [DeviceModule], counterpart to
// the legacy AT+ fetcher (relay_module_status_fetcher.dart). Implements the
// recommended connection sequence from doc/Soleux-Mobile-TCP-Protocol.md:
//
//   1. `hello`
//   2. `get_relay_configuration`
//   3. build the UI from returned counts, fields, and device identity
//
// Reconciliation applies the same "user names are persistent" rule as the AT+
// path: existing channel/input names are never overwritten by the device; new
// entries take the device-reported names. Dimmer outputs pick up PWM/brightness
// from the configuration when present.
import 'package:flutter/material.dart';

import '../../core/soleux/soleux_device_family.dart';
import '../../models/models.dart';

/// Parsed `hello` result.
class SoleuxHelloData {
  final int protocol;
  final String device;
  final String name;
  final int inputCount;
  final int virtualInputCount;
  final int outputCount;

  const SoleuxHelloData({
    required this.protocol,
    required this.device,
    this.name = '',
    this.inputCount = 0,
    this.virtualInputCount = 0,
    this.outputCount = 0,
  });

  factory SoleuxHelloData.fromResult(Map<String, dynamic> result) =>
      SoleuxHelloData(
        protocol: result['protocol'] is num
            ? (result['protocol'] as num).toInt()
            : 0,
        device: result['device'] as String? ?? '',
        name: result['name'] as String? ?? '',
        inputCount: _int(result['input_count']),
        virtualInputCount: _int(result['virtual_input_count']),
        outputCount: _int(result['output_count']),
      );

  /// Device family reported by `device`, when known.
  SoleuxDeviceFamily? get family =>
      SoleuxDeviceFamilies.fromJsonDevice(device);
}

/// One `outputs[]` entry from `get_relay_configuration`.
class SoleuxOutputState {
  final int channel;
  final String name;
  final bool state;
  final int? pwm;

  /// Timed/behavioural fields are surfaced raw for future pages.
  final Map<String, dynamic> raw;

  const SoleuxOutputState({
    required this.channel,
    this.name = '',
    this.state = false,
    this.pwm,
    this.raw = const {},
  });

  factory SoleuxOutputState.fromJson(Map<String, dynamic> json) {
    final pwmRaw = json['pwm'];
    final channel = _int(json['channel']);
    return SoleuxOutputState(
      channel: channel,
      name: json['output_name'] as String? ??
          json['name'] as String? ??
          '',
      state: json['output_state'] as bool? ?? false,
      pwm: pwmRaw is num ? pwmRaw.toInt() : null,
      raw: json,
    );
  }
}

/// One `inputs[]` entry from `get_relay_configuration`.
class SoleuxInputState {
  final int channel;
  final String name;
  final bool state;
  final bool enabled;

  const SoleuxInputState({
    required this.channel,
    this.name = '',
    this.state = false,
    this.enabled = true,
  });

  factory SoleuxInputState.fromJson(Map<String, dynamic> json) {
    final enabledRaw = json['input_enabled'];
    return SoleuxInputState(
      channel: _int(json['channel']),
      name: json['input_name'] as String? ?? json['name'] as String? ?? '',
      state: json['input_state'] as bool? ?? false,
      enabled: enabledRaw is bool
          ? enabledRaw
          : (enabledRaw as num? ?? 1) != 0,
    );
  }
}

/// Parsed `get_relay_configuration` result.
class SoleuxRelayConfiguration {
  final int inputCount;
  final int virtualInputCount;
  final int outputCount;
  final List<SoleuxOutputState> outputs;
  final List<SoleuxInputState> inputs;

  const SoleuxRelayConfiguration({
    this.inputCount = 0,
    this.virtualInputCount = 0,
    this.outputCount = 0,
    this.outputs = const [],
    this.inputs = const [],
  });

  factory SoleuxRelayConfiguration.fromResult(Map<String, dynamic> result) =>
      SoleuxRelayConfiguration(
        inputCount: _int(result['input_count']),
        virtualInputCount: _int(result['virtual_input_count']),
        outputCount: _int(result['output_count']),
        outputs: [
          for (final o in result['outputs'] is List ? result['outputs'] as List : const [])
            if (o is Map)
              SoleuxOutputState.fromJson(Map<String, dynamic>.from(o)),
        ],
        inputs: [
          for (final i in result['inputs'] is List ? result['inputs'] as List : const [])
            if (i is Map)
              SoleuxInputState.fromJson(Map<String, dynamic>.from(i)),
        ],
      );
}

int _int(Object? value) => value is num ? value.toInt() : 0;

/// Applies Soleux JSON `hello` + `get_relay_configuration` results onto a
/// module, preserving user-defined names.
class SoleuxJsonFetcher {
  const SoleuxJsonFetcher();

  void apply(DeviceModule module, SoleuxHelloData? hello) {
    if (hello == null) return;
    if (hello.name.isNotEmpty) module.name = hello.name;
  }

  void applyConfiguration(
      DeviceModule module, SoleuxRelayConfiguration config) {
    final targetOutputs = config.outputCount > 0
        ? config.outputCount
        : (config.outputs.isEmpty
            ? module.channels.length
            : (config.outputs.map((o) => o.channel).fold<int>(
                        0, (a, b) => a > b ? a : b) +
                    1));

    final stdoutNames = {
      for (final o in config.outputs) o.channel: o.name,
    };
    while (module.channels.length < targetOutputs) {
      final index = module.channels.length;
      final deviceName = stdoutNames[index];
      module.channels.add(ChannelOutput(
        id: '${module.id}c${index + 1}',
        name: (deviceName != null && deviceName.isNotEmpty)
            ? deviceName
            : 'Output ${index + 1}',
        icon: Icons.power,
      ));
    }
    if (module.channels.length > targetOutputs) {
      module.channels.removeRange(targetOutputs, module.channels.length);
    }

    for (final output in config.outputs) {
      final index = output.channel;
      if (index < 0 || index >= module.channels.length) continue;
      final channel = module.channels[index];
      channel.isOn = output.state;
      // Dimmer outputs expose PWM as a bounded value supplied by firmware
      // metadata; persist it as the channel brightness (0-100%).
      if (output.pwm != null) {
        channel.brightness = output.pwm!.clamp(0, 100);
      }
      // Only seed the name for freshly created channels; never overwrite a
      // user-customised name.
      if (channel.name == 'Output ${index + 1}' && output.name.isNotEmpty) {
        channel.name = output.name;
      }
    }

    final targetInputs = config.inputs.isEmpty
        ? module.inputs.length
        : (config.inputs.map((i) => i.channel).fold<int>(
                    0, (a, b) => a > b ? a : b) +
                1);
    final inputNames = {
      for (final i in config.inputs) i.channel: i.name,
    };
    while (module.inputs.length < targetInputs) {
      final index = module.inputs.length;
      final deviceName = inputNames[index];
      module.inputs.add(PhysicalInput(
        id: '${module.id}i${index + 1}',
        label: (deviceName != null && deviceName.isNotEmpty)
            ? deviceName
            : 'Switch ${index + 1}',
        mode: InputMode.toggle,
      ));
    }
    if (module.inputs.length > targetInputs) {
      module.inputs.removeRange(targetInputs, module.inputs.length);
    }
  }
}