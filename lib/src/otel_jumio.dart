// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_jumio_suppression.dart';

const _tracerName = 'dartastic_otel_libs_jumio';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class JumioResult {
  const JumioResult({
    this.accountId,
    this.workflowExecutionId,
    this.status,
    this.decision,
    this.workflowDefinitionId,
    this.capabilitiesUsed,
    this.idType,
    this.usabilityScore,
    this.dataCenter,
    this.requestId,
    this.statusCode,
  });

  /// `accountId`.
  final String? accountId;

  /// `workflowExecutionId`.
  final String? workflowExecutionId;

  /// `INITIATED` / `ACQUIRED` / `PROCESSED` / `SESSION_EXPIRED` /
  /// `TOKEN_EXPIRED`.
  final String? status;

  /// `PASSED` / `WARNING` / `REJECTED` / `NOT_EXECUTED`. Jumio
  /// distinguishes a softer WARNING from outright REJECTED.
  final String? decision;

  /// `workflowDefinitionId` (numeric) — distinct verification flow.
  final int? workflowDefinitionId;

  /// Comma-joined Jumio capabilities used: `extraction`,
  /// `liveness`, `similarity`, `usability`, `dataChecks`, `imageChecks`,
  /// `watchlistScreening`, `proofOfResidency`, `riskScreening`,
  /// `authentication`. Each capability is billed.
  final String? capabilitiesUsed;

  /// `ID_CARD` / `PASSPORT` / `DRIVING_LICENSE` / `VISA` / `RESIDENCE_PERMIT`.
  final String? idType;

  /// Usability score (0-100) for the captured ID image.
  final int? usabilityScore;

  /// `US` / `EU` / `SG` — Jumio data center routing.
  final String? dataCenter;

  /// `X-Jumio-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class JumioCallResult<T> {
  const JumioCallResult({required this.value, this.result});
  final T value;
  final JumioResult? result;
}

/// Wraps a Jumio KYX API call in a CLIENT span. [operation] is one of
/// `accounts.create`, `accounts.update`, `accounts.get`,
/// `workflow_executions.create`, `workflow_executions.get`,
/// `workflow_executions.list`, `workflow_executions.credentials`,
/// `data.get`, `images.get`, `webhooks.create`, `screening.create`,
/// `authentication.create`.
Future<T> tracedJumio<T>({
  required String operation,
  required Future<JumioCallResult<T>> Function() invoke,
  String? dataCenter,
}) async {
  if (jumioInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'jumio',
    'rpc.method': operation,
    'jumio.operation': operation,
  };
  if (dataCenter != null) m['jumio.data_center'] = dataCenter;

  final span = _tracer().startSpan(
    'jumio $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.accountId != null) {
        extras.add(OTel.attributeString(
          'jumio.account.id',
          r.result!.accountId!,
        ));
      }
      if (r.result!.workflowExecutionId != null) {
        extras.add(OTel.attributeString(
          'jumio.workflow_execution.id',
          r.result!.workflowExecutionId!,
        ));
      }
      if (r.result!.status != null) {
        extras.add(OTel.attributeString(
          'jumio.status',
          r.result!.status!,
        ));
        if (r.result!.status == 'SESSION_EXPIRED' ||
            r.result!.status == 'TOKEN_EXPIRED') {
          span.setStatus(
            SpanStatusCode.Error,
            'Jumio ${r.result!.status}',
          );
        }
      }
      if (r.result!.decision != null) {
        extras.add(OTel.attributeString(
          'jumio.decision',
          r.result!.decision!,
        ));
        if (r.result!.decision == 'REJECTED') {
          span.setStatus(
            SpanStatusCode.Error,
            'Jumio decision REJECTED',
          );
        }
      }
      if (r.result!.workflowDefinitionId != null) {
        extras.add(OTel.attributeInt(
          'jumio.workflow_definition.id',
          r.result!.workflowDefinitionId!,
        ));
      }
      if (r.result!.capabilitiesUsed != null) {
        extras.add(OTel.attributeString(
          'jumio.capabilities',
          r.result!.capabilitiesUsed!,
        ));
      }
      if (r.result!.idType != null) {
        extras.add(OTel.attributeString(
          'jumio.id.type',
          r.result!.idType!,
        ));
      }
      if (r.result!.usabilityScore != null) {
        extras.add(OTel.attributeInt(
          'jumio.usability.score',
          r.result!.usabilityScore!,
        ));
      }
      if (r.result!.dataCenter != null) {
        extras.add(OTel.attributeString(
          'jumio.data_center',
          r.result!.dataCenter!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'jumio.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Jumio HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
