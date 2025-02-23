package TTMp32Gme::DbUpdate;

use strict;
use warnings;

my $updates = {
	'0.1.0' => <<'END',
UPDATE "config" SET value='0.1.0' WHERE param='version';
END
	'0.2.0' => <<'END',
UPDATE "config" SET value='0.2.0' WHERE param='version';
END
	'0.2.1' => <<'END',
UPDATE "config" SET value='0.2.1' WHERE param='version';
END
	'0.2.3' => <<'END',
UPDATE "config" SET value='0.2.3' WHERE param='version';
INSERT INTO "config" ("param", "value") VALUES ('pen_language', 'GERMAN');
END
	'0.3.0' => <<'END',
UPDATE "config" SET value='0.3.0' WHERE param='version';
INSERT INTO "config" ("param", "value") VALUES ('library_path', '');
INSERT INTO "config" ("param", "value") VALUES ('player_mode', 'music');
END
	'0.3.1' => <<'END',
UPDATE "config" SET value='0.3.1' WHERE param='version';
DELETE FROM "config" WHERE param='player_mode';
ALTER TABLE "gme_library" ADD COLUMN "player_mode" TEXT DEFAULT 'music';
END
	'1.0.0' => <<'END',
UPDATE "config" SET value='1.0.0' WHERE param='version';
END
};

sub update {
	my ( $dbVersion, $dbh ) = @_;

	foreach my $u ( sort keys %{$updates} ) {
		if ( Perl::Version->new($u)->numify > $dbVersion->numify ) {
			my $batch = DBIx::MultiStatementDo->new( dbh => $dbh );
			$batch->do( $updates->{$u} )
				or die "Can't update config file.\n\tError: " . $batch->dbh->errstr . "\n";
		}
	}

	return 1;
}

1;
