part of '../main.dart';

abstract class OjProvider {
  Future<OjProfile> fetchProfile(http.Client client, String username);
}
