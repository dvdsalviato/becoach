import 'package:flutter/material.dart';

import 'models.dart';
import 'ui/common/widgets.dart';

/// Android: apre Google Calendar con l'evento compilato.
Future<void> addToCalendar(BuildContext context, Appointment a, String ics, String googleLink) =>
    openUrl(context, googleLink);
