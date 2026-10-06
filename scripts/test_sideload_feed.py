"""Source and publication regressions. All GitHub calls are mocked; nothing is published."""
import base64
import copy
import importlib.util
import json
import os
import plistlib
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from sideload_feed import BUNDLE_IDS, ENTRY_FILE, make_entry, merge_source, source_url

spec = importlib.util.spec_from_file_location('publisher', Path(__file__).with_name('publish-release.py'))
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)
REPO = 'example/CardioLog'
SHA = 'a' * 40


def build_fixture(folder, channel='dev', version='0.1.0', build='1.0.1'):
    folder.mkdir(parents=True, exist_ok=True)
    info = {
        'channel': channel, 'bundleID': BUNDLE_IDS[channel], 'version': version, 'build': build,
        'commit': SHA, 'sourceDirty': False, 'unsigned': True, 'minimumOS': '26.0',
        'createdAt': '2026-10-06T00:00:00+00:00', 'xcode': 'Xcode fixture', 'sdk': '26.2',
        'ciRunURL': 'https://github.com/example/CardioLog/actions/runs/1',
    }
    (folder / 'build-info.json').write_text(json.dumps(info))
    (folder / 'expected-entitlements.plist').write_bytes(plistlib.dumps({'com.apple.developer.healthkit': True}))
    app = {
        'CFBundleIdentifier': BUNDLE_IDS[channel], 'CFBundleShortVersionString': version,
        'CFBundleVersion': build, 'MinimumOSVersion': '26.0', 'CardioLogCommit': SHA,
        'CardioLogChannel': channel, 'NSBluetoothAlwaysUsageDescription': 'Connect to your sensor.',
    }
    with zipfile.ZipFile(folder / 'CardioLog test.ipa', 'w') as archive:
        archive.writestr('Payload/CardioLog.app/Info.plist', plistlib.dumps(app))
    (folder / 'SHA256SUMS.txt').write_text('fixture: the publication tests mock checksum verification\n')
    return info


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def entry(self, channel='dev', version='0.1.0', build='1.0.1'):
        folder = self.root / channel
        build_fixture(folder, channel, version, build)
        tag = 'v' + version if channel == 'release' else 'dev-1.' + build.split('.')[-1]
        return make_entry(REPO, tag, folder)

    def test_exact_ipa_metadata_permissions_and_legacy_fields(self):
        entry = self.entry()
        app = entry['app']
        version = app['versions'][0]
        self.assertEqual(app['bundleIdentifier'], 'app.cardiolog.dev')
        self.assertEqual(version['buildVersion'], '1.0.1')
        self.assertEqual(version['minOSVersion'], '26.0')
        self.assertEqual(version['size'], (self.root / 'dev/CardioLog test.ipa').stat().st_size)
        self.assertTrue(version['downloadURL'].endswith('/CardioLog%20test.ipa'))
        self.assertEqual(app['downloadURL'], version['downloadURL'])
        self.assertEqual(app['appPermissions'], {
            'entitlements': ['com.apple.developer.healthkit'],
            'privacy': {'NSBluetoothAlwaysUsageDescription': 'Connect to your sensor.'},
        })
        self.assertIn('/' + SHA + '/', app['iconURL'])

    def test_dev_first_and_independent_release_versions(self):
        source = merge_source(REPO, None, self.entry())
        self.assertEqual([a['name'] for a in source['apps']], ['CardioLog Dev'])
        source = merge_source(REPO, source, self.entry('release'))
        stable = copy.deepcopy(source['apps'][0])
        source = merge_source(REPO, source, self.entry(build='1.0.2'))
        self.assertEqual(source['apps'][0], stable)
        self.assertEqual([a['name'] for a in source['apps']], ['CardioLog', 'CardioLog Dev'])
        self.assertEqual([v['buildVersion'] for v in source['apps'][1]['versions']], ['1.0.2', '1.0.1'])
        self.assertEqual(source['sourceURL'], source_url(REPO))

    def test_numeric_order_and_older_release_does_not_roll_back(self):
        source = merge_source(REPO, None, self.entry('release', '1.10.0', '1.0.10'))
        source = merge_source(REPO, source, self.entry('release', '1.9.0', '1.0.20'))
        self.assertEqual(source['apps'][0]['version'], '1.10.0')
        self.assertIn('/v1.10.0/', source['apps'][0]['downloadURL'])
        dev = merge_source(REPO, None, self.entry(build='1.0.10'))
        dev = merge_source(REPO, dev, self.entry(build='1.0.9'))
        self.assertEqual(dev['apps'][0]['buildVersion'], '1.0.10')

    def test_idempotence_and_immutable_version_protection(self):
        entry = self.entry()
        source = merge_source(REPO, None, entry)
        self.assertEqual(source, merge_source(REPO, source, entry))
        entry['app']['versions'][0]['size'] += 1
        with self.assertRaisesRegex(ValueError, 'already-published'):
            merge_source(REPO, source, entry)

    def test_identity_and_uncommitted_builds_are_rejected(self):
        folder = self.root / 'dev'
        baseline = build_fixture(folder)
        for key, value in [('bundleID', 'another.app'), ('commit', 'uncommitted'),
                           ('sourceDirty', True), ('version', '9.0.0'), ('build', '2.0.0')]:
            with self.subTest(key=key):
                info = {**baseline, key: value}
                (folder / 'build-info.json').write_text(json.dumps(info))
                with self.assertRaises(ValueError):
                    make_entry(REPO, 'dev-1.1', folder)

    def test_stable_tag_and_source_repository_must_match(self):
        build_fixture(self.root / 'release', 'release')
        with self.assertRaisesRegex(ValueError, 'tag'):
            make_entry(REPO, 'v9.0.0', self.root / 'release')
        entry = self.entry()
        with self.assertRaisesRegex(ValueError, 'different repository'):
            merge_source(REPO, {'identifier': 'some.other.source'}, entry)

    def test_source_creation_and_optimistic_updates(self):
        first = self.entry()
        with patch.object(publisher, 'github_json', return_value=None), patch.object(publisher, 'write_api') as write:
            publisher.publish_source(REPO, SHA, first)
        calls = write.call_args_list
        self.assertEqual(calls[0].args[1]['ref'], 'refs/heads/sideload')
        payload = calls[1].args[1]
        self.assertNotIn('sha', payload)
        source = json.loads(base64.b64decode(payload['content']))
        current = {'sha': 'file-sha', 'encoding': 'base64', 'content': payload['content']}
        second = self.entry('release')
        with patch.object(publisher, 'github_json', side_effect=[current, {'ref': 'refs/heads/sideload'}]), patch.object(publisher, 'write_api') as write:
            publisher.publish_source(REPO, SHA, second)
        self.assertEqual(write.call_count, 1)
        self.assertEqual(write.call_args.args[1]['sha'], 'file-sha')
        merged = json.loads(base64.b64decode(write.call_args.args[1]['content']))
        self.assertEqual(merged['apps'][1], source['apps'][0])

    def test_authentication_failure_is_not_treated_as_empty_feed(self):
        result = subprocess.CompletedProcess([], 1, '', 'gh: Forbidden (HTTP 403)')
        with patch.object(publisher, 'gh', return_value=result), patch.object(publisher, 'write_api') as write:
            with self.assertRaisesRegex(RuntimeError, 'Forbidden'):
                publisher.publish_source(REPO, SHA, self.entry())
        write.assert_not_called()

    def test_published_ipa_must_exist_and_match_feed(self):
        entry = self.entry()
        version = entry['app']['versions'][0]
        release = {'draft': False, 'tag_name': entry['tag'], 'prerelease': True,
                   'assets': [{'name': 'CardioLog test.ipa', 'size': version['size']}]}
        publisher.validate_published_entry(entry, release, REPO, SHA, 'dev', entry['tag'])
        release['assets'][0]['size'] += 1
        with self.assertRaisesRegex(ValueError, 'uploaded IPA'):
            publisher.validate_published_entry(entry, release, REPO, SHA, 'dev', entry['tag'])

    def test_failed_ipa_publication_never_updates_feed(self):
        folder = self.root / 'downloads/unsigned-release-1-1'
        build_fixture(folder, 'release')
        env = {'GITHUB_REF': 'refs/tags/v0.1.0', 'GITHUB_REF_NAME': 'v0.1.0', 'GITHUB_SHA': SHA,
               'GITHUB_RUN_NUMBER': '1', 'GITHUB_RUN_ATTEMPT': '1', 'GH_REPO': REPO, 'CHANNELS': '["release"]', 'GITHUB_STEP_SUMMARY': ''}
        previous_cwd = Path.cwd()
        os.chdir(self.root)
        try:
            with patch.dict(os.environ, env), patch.object(publisher.subprocess, 'run'), \
                 patch.object(publisher, 'github_json', return_value=None), \
                 patch.object(publisher, 'gh', side_effect=RuntimeError('Upload failed')), \
                 patch.object(publisher, 'publish_source') as publish:
                with self.assertRaisesRegex(RuntimeError, 'Upload failed'):
                    publisher.main()
                publish.assert_not_called()
        finally:
            os.chdir(previous_cwd)

    def test_stable_retry_repairs_feed_using_original_published_build(self):
        original = self.entry('release')
        build_fixture(self.root / 'downloads/unsigned-release-1-2', 'release', build='1.0.2')
        release = {'draft': False, 'tag_name': 'v0.1.0', 'prerelease': False,
                   'assets': [{'name': 'CardioLog test.ipa', 'size': original['app']['size']}]}
        env = {'GITHUB_REF': 'refs/tags/v0.1.0', 'GITHUB_REF_NAME': 'v0.1.0', 'GITHUB_SHA': SHA,
               'GITHUB_RUN_NUMBER': '1', 'GITHUB_RUN_ATTEMPT': '2', 'GH_REPO': REPO, 'CHANNELS': '["release"]', 'GITHUB_STEP_SUMMARY': ''}
        def download(*args, **kwargs):
            self.assertEqual(args[:2], ('release', 'download'))
            destination = Path(args[args.index('--dir') + 1]) / ENTRY_FILE
            destination.write_text(json.dumps(original))
        previous_cwd = Path.cwd()
        os.chdir(self.root)
        try:
            with patch.dict(os.environ, env), patch.object(publisher.subprocess, 'run'), \
                 patch.object(publisher, 'github_json', return_value=release), \
                 patch.object(publisher, 'gh', side_effect=download), \
                 patch.object(publisher, 'publish_source') as publish:
                publisher.main()
                self.assertEqual(publish.call_args.args[2]['app']['buildVersion'], '1.0.1')
        finally:
            os.chdir(previous_cwd)

    def test_new_dev_publication_updates_feed_after_ipa_before_pointer(self):
        folder = self.root / 'downloads/unsigned-dev-1-1'
        build_fixture(folder)
        entry = make_entry(REPO, 'dev-1.1', folder)
        events = []
        release = {'draft': False, 'tag_name': 'dev-1.1', 'prerelease': True,
                   'assets': [{'name': 'CardioLog test.ipa', 'size': entry['app']['size']}]}
        env = {'GITHUB_REF': 'refs/heads/main', 'GITHUB_REF_NAME': 'main', 'GITHUB_SHA': SHA,
               'GITHUB_RUN_NUMBER': '1', 'GITHUB_RUN_ATTEMPT': '1', 'GH_REPO': REPO,
               'CHANNELS': '["dev"]', 'GITHUB_STEP_SUMMARY': ''}
        def api(endpoint, missing_ok=False):
            if endpoint.endswith('/git/ref/heads/main'):
                return {'object': {'sha': SHA}}
            if endpoint.endswith('/releases/tags/latest-dev'):
                return None
            if endpoint.endswith('/releases/tags/dev-1.1'):
                return release if events else None
            self.fail(f'Unexpected API request: {endpoint}')
        def create(*args, **kwargs):
            self.assertEqual(args[:2], ('release', 'create'))
            events.append(args[2])
            if args[2] == 'dev-1.1':
                metadata = next(Path(a) for a in args if a.endswith('/' + ENTRY_FILE))
                self.assertEqual(json.loads(metadata.read_text()), entry)
        previous_cwd = Path.cwd()
        os.chdir(self.root)
        try:
            with patch.dict(os.environ, env), patch.object(publisher.subprocess, 'run'), \
                 patch.object(publisher, 'github_json', side_effect=api), \
                 patch.object(publisher, 'gh', side_effect=create), \
                 patch.object(publisher, 'publish_source', side_effect=lambda *args: events.append('feed')):
                publisher.main()
            self.assertEqual(events, ['dev-1.1', 'feed', 'latest-dev'])
        finally:
            os.chdir(previous_cwd)

    def test_stale_dev_build_does_not_publish_assets_or_source(self):
        build_fixture(self.root / 'downloads/unsigned-dev-1-1')
        env = {'GITHUB_REF': 'refs/heads/main', 'GITHUB_SHA': SHA, 'GITHUB_RUN_NUMBER': '1',
               'GITHUB_RUN_ATTEMPT': '1', 'GH_REPO': REPO, 'CHANNELS': '["dev"]'}
        previous_cwd = Path.cwd()
        os.chdir(self.root)
        try:
            with patch.dict(os.environ, env), patch.object(publisher.subprocess, 'run'), \
                 patch.object(publisher, 'github_json', return_value={'object': {'sha': 'b' * 40}}), \
                 patch.object(publisher, 'gh') as release, patch.object(publisher, 'publish_source') as source:
                publisher.main()
                release.assert_not_called()
                source.assert_not_called()
        finally:
            os.chdir(previous_cwd)


if __name__ == '__main__':
    unittest.main()
