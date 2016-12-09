### Building a release for vote:

1. Grab a clean checkout for safety.
2. Run: "git checkout ${BRANCH}" to switch to branch of the intended release point.
3. Update the versions etc:
  - VERSION.txt
  - management/python/setup.py
  - docs/man/qpidd.1 (and the date)
  - src/amqp.cmake (ensure current proton release is marked tested)
4. Commit the changes, tag them.
  - Run: "git add ."
  - Run: 'git commit -m "update versions for ${TAG}"'
  - Run: 'git tag -m "tag ${TAG}" ${TAG}'
  - Push changes. Optionally save this bit for later.
5. Run: "bin/export.sh $PWD ${TAG}" to create the qpid-cpp-${TAG}.tar.gz release archive.
6. Create signature and checksums for the archive:
  - Rename if needed, e.g "mv qpid-cpp-${TAG}.tar.gz qpid-cpp-${VERSION}.tar.gz"
  - e.g "gpg --detach-sign --armor qpid-cpp-${VERSION}.tar.gz"
  - e.g "sha1sum qpid-cpp-${VERSION}.tar.gz > qpid-cpp-${VERSION}.tar.gz.sha1"
  - e.g "md5sum qpid-cpp-${VERSION}.tar.gz > qpid-cpp-${VERSION}.tar.gz.md5"
7. Commit artifacts to dist dev repo in https://dist.apache.org/repos/dist/dev/qpid/cpp/${TAG} dir.
8. Bump the branch versions to next 1.x.y-SNAPSHOT (and master if it wasn't already).
9. Send email, provide links to dist dev repo

### After a vote succeeds:

1. Tag the RC with the final name/version.
2. Commit the artifacts to dist release repo in https://dist.apache.org/repos/dist/release/qpid/cpp/${VERSION} dir:
3. Give the mirrors some time to distribute things.
4. Update the website with release content.
5. Send release announcement email.
