import 'package:flutter/material.dart';

enum AlertSeverity { info, warning, danger, critical }

class SafetyAlert {
  SafetyAlert({
    required this.title,
    required this.message,
    required this.severity,
    required this.unitSource,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String title;
  final String message;
  final AlertSeverity severity;
  final String unitSource;
  final DateTime timestamp;

  static AlertSeverity parseSeverity(String s) {
    switch (s.toLowerCase()) {
      case 'critical': return AlertSeverity.critical;
      case 'danger':   return AlertSeverity.danger;
      case 'warning':  return AlertSeverity.warning;
      default:         return AlertSeverity.info;
    }
  }
}

class DrivoraSensorData {
  DrivoraSensorData({
    this.frontState = 0,
    this.frontStateName = 'CLEAR',
    this.frontStateColor = const Color(0xFF1DB954),
    this.frontDistance = -1.0,
    this.closingSpeed = 0.0,
    this.frontOnline = false,
    this.leanRiskLevel = 0,
    this.leanRiskName = 'SAFE',
    this.roll = 0.0,
    this.pitch = 0.0,
    this.confidence = 1.0,
    this.leanOnline = false,
    this.leanCalibrated = false,
    this.criticalRollDeg = 30.0,
    this.criticalPitchDeg = 20.0,
    // --- overall rear state (derived from overallState on hub) ---
    this.rearState = 0,
    this.rearStateName = 'CLEAR',
    this.rearStateColor = const Color(0xFF1DB954),
    this.rearDistance = -1.0,
    this.rearOnline = false,
    // --- per-sensor rear data (left / center / right) ---
    this.rearLeftState = 0,
    this.rearLeftStateName = 'CLEAR',
    this.rearLeftColor = const Color(0xFF1DB954),
    this.rearLeftDistanceCm = -1.0,
    this.rearCenterState = 0,
    this.rearCenterStateName = 'CLEAR',
    this.rearCenterColor = const Color(0xFF1DB954),
    this.rearCenterDistanceCm = -1.0,
    this.rearRightState = 0,
    this.rearRightStateName = 'CLEAR',
    this.rearRightColor = const Color(0xFF1DB954),
    this.rearRightDistanceCm = -1.0,
    this.laneState = 0,
    this.laneStateName = 'SAFE',
    this.laneStateColor = const Color(0xFF1DB954),
    this.laneOnline = false,
    this.ldwActive = false,
    this.speed = 0.0,
    this.brakeActive = false,
    this.lateralG = 0.0,
  });

  // --- FRONT UNIT (FCW) ---
  final int frontState;
  final String frontStateName;
  final Color frontStateColor;
  final double frontDistance;
  final double closingSpeed;
  final bool frontOnline;

  // --- LEAN UNIT (COG) ---
  final int leanRiskLevel;
  final String leanRiskName;
  final double roll;
  final double pitch;
  final double confidence;
  final bool leanOnline;
  final bool leanCalibrated;
  final double criticalRollDeg;
  final double criticalPitchDeg;

  // --- REAR UNIT — overall (driven by hub's overallState) ---
  final int rearState;
  final String rearStateName;
  final Color rearStateColor;
  final double rearDistance;     // min of the three sensor distances
  final bool rearOnline;

  // --- REAR UNIT — per-sensor (L / C / R) ---
  final int rearLeftState;
  final String rearLeftStateName;
  final Color rearLeftColor;
  final double rearLeftDistanceCm;

  final int rearCenterState;
  final String rearCenterStateName;
  final Color rearCenterColor;
  final double rearCenterDistanceCm;

  final int rearRightState;
  final String rearRightStateName;
  final Color rearRightColor;
  final double rearRightDistanceCm;

  // --- LANE UNIT (LDW) ---
  final int laneState;
  final String laneStateName;
  final Color laneStateColor;
  final bool laneOnline;

  // --- VIRTUAL / DERIVED ---
  final bool ldwActive;
  final double speed;
  final bool brakeActive;
  final double lateralG;

  // Legacy getters used by other screens
  bool get unitAOnline => frontOnline;
  bool get unitBOnline => rearOnline;
  bool get unitCOnline => leanOnline;
  bool get unitDOnline => laneOnline;
  double get ttc => (closingSpeed > 0 && frontDistance > 0) ? (frontDistance / closingSpeed) : 10.0;
  double get tiltAngle => roll;
  double get rearClearance => rearDistance;

  Color get frontColor => frontStateColor;
  Color get rearColor  => rearStateColor;
  Color get laneColor  => laneStateColor;
}
