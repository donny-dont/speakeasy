// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library speakeasy.src.repository.copy_and_write_repository;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:pub_server/repository.dart';

final Logger _logger = new Logger('speakeasy.src.repository.copy_and_write_repository;');

/// A [CopyAndWriteRepository] writes to one repository and directs
/// read-misses to another repository.
///
/// Package versions not available from the read-write repository will be
/// fetched from a read-fallback repository and uploaded to the read-write
/// repository. This effectively caches all packages requested through this
/// [CopyAndWriteRepository].
///
/// New package versions which get uploaded will be stored only locally.
class CopyAndWriteRepository extends PackageRepository {
  final PackageRepository local;
  final PackageRepository remote;
  final _RemoteMetadataCache _localCache;
  final _RemoteMetadataCache _remoteCache;

  /// Construct a new proxy with [local] as the local [PackageRepository] which
  /// is used for uploading new package versions to and [remote] as the
  /// read-only [PackageRepository] which is consulted on misses in [local].
  CopyAndWriteRepository(PackageRepository local, PackageRepository remote)
      : this.local = local,
        this.remote = remote,
        this._localCache = new _RemoteMetadataCache(local),
        this._remoteCache = new _RemoteMetadataCache(remote);

  Stream<PackageVersion> versions(String package) async* {

    for (_RemoteMetadataCache repo in [_localCache,_remoteCache]) {
      List<PackageVersion> _versions = await repo.fetchVersionlist(
          package);
      for (PackageVersion _version in _versions) {
        yield _version;
      }
    }

  }

  Future<PackageVersion> lookupVersion(String package, String version) {
    return versions(package)
        .where((pv) => pv.versionString == version)
        .toList().then((List<PackageVersion> versions) {
      if (versions.length >= 1) return versions.first;
      return null;
    });
  }

  Future<Stream> download(String package, String version) async {
    var packageVersion = await local.lookupVersion(package, version);

    if (packageVersion != null) {
      _logger.info('Serving $package/$version from local repository.');
      return local.download(package, packageVersion.versionString);
    } else {
      // We first download the package from the remote repository and store
      // it locally. Then we read the local version and return it.

      _logger.info('Downloading $package/$version from remote repository.');
      var stream = await remote.download(package, version);

      _logger.info('Upload $package/$version to local repository.');
      await local.upload(stream);

      _logger.info('Serving $package/$version from local repository.');
      return local.download(package, version);
    }
  }

  bool get supportsUpload => true;

  Future upload(Stream<List<int>> data) {
    _logger.info('Starting upload to local package repository.');
    // TODO: Converting this to an async scope makes the stream not get any data
    // or done event. Seems like there is still an issue in
    // package:mime - making this an async scope results in this stream getting
    // no data.
    return local.upload(data).then((data) {
      // TODO: It's not really necessary to invalidate all.
      _logger.info('Upload finished. Invalidating in-memory cache.');
      _localCache.invalidateAll();
    });
  }

  bool get supportsAsyncUpload => false;
}

/// A cache for [PackageVersion] objects for a given `package`.
///
/// The constructor takes a [PackageRepository] which will be used to populate
/// the cache.
class _RemoteMetadataCache {
  final PackageRepository remote;

  Map<String, Set<PackageVersion>> _versions = {};
  Map<String,DateTime> _expires ={};
  Map<String, Completer<Set<PackageVersion>>> _versionCompleters = {};

  _RemoteMetadataCache(this.remote);


  Future<List<PackageVersion>> fetchVersionlist(String package) {
    DateTime now = new DateTime.now();
    new Map<String,DateTime>()
      ..addAll(_expires)
      ..forEach((String package,DateTime val)  {
        if (now.isAfter(val)) {
          _expires.remove(package);
          _versions.remove(package);
          _versionCompleters.remove(package);
        }
      });


    return _versionCompleters.putIfAbsent(package, () {
      var c = new Completer();

      _versions.putIfAbsent(package, () => new Set());
      remote.versions(package).toList().then((versions) {
        _versions[package].addAll(versions);
        _expires[package] = now.add(new Duration(minutes:10));
        c.complete(_versions[package]);
      });

      return c;
    }).future.then((set) => set.toList());
  }

  void addVersion(String package, PackageVersion version) {
    _versions.putIfAbsent(version.packageName, () => new Set()).add(version);
  }

  void invalidateAll() {
    _versionCompleters.clear();
    _versions.clear();
  }
}
