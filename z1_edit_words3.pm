package z1_edit_words3;
use utf8;

my $config = {
	'友達' =>
		[
			'友人',
			'旧友',
			'親友',
			'盟友',
			'友',
		],
	'格別' =>
		[
			'特別',
			'格別', # 通常は不要。『こころ』には複数の品詞の「格別」があった
		],          # ので，1つの「格別」にまとめるために指定。
	'偶然' =>
		[
			'偶然', # 形容動詞・副詞・副詞可能の「偶然」を1種類の語にまとめる
		],
};

use strict;

#---------------------------#
#   Setting of this plugin  #

sub plugin_config{
	return {
		name     => '表記ゆれの吸収',
		menu_cnf => 2,
		menu_grp => '',
	};
}

#-------------#
#   command   #

sub exec{
	my $self = shift;
	my $mw = $::main_gui->{win_obj};

	# list up existing units
	my @avail = ();
	foreach my $tani ('bun','dan','h1','h2','h3','h4','h5'){
		if ( mysql_exec->table_exists($tani) ){
			push @avail, $tani;
		}
	}

	# try finding mother
	foreach my $i (keys %{$config}){
		# search for parents
		my $hdl2 = mysql_exec->select("
			SELECT genkei.id, genkei.num
			FROM   genkei
			WHERE  genkei.name = '$i'
			ORDER BY id
			LIMIT 1
		",1)->hundle->fetch;

		print "mother: $i, ";

		if ($hdl2){            # found
			print "ok.";
		} else {               # not found
			print "ng, ";
			my $new = '';
			foreach my $h (@{$config->{$i}}){ # search for mother candidate?
				my $hdl2 = mysql_exec->select("
					SELECT genkei.id, genkei.num
					FROM   genkei
					WHERE  genkei.name = '$h'
					LIMIT 1
				",1)->hundle->fetch;
				if ($hdl2){
					$new = $hdl2->[0];
					last;
				}
			}
			if (length($new)){                # parents candidate found
				mysql_exec->do("
					UPDATE genkei
					SET   name = '$i'
					WHERE id = '$new'
				",1);
				print "replaced";
			}
		}
		print "\n";
	}

	# get required info
	my ($hyoso, $genkei);
	foreach my $i (keys %{$config}){

		# parent
		my $hdl = mysql_exec->select("
			SELECT genkei.id, genkei.num
			FROM   genkei
			WHERE  genkei.name = '$i'
			ORDER BY id
			LIMIT 1
		",1)->hundle->fetch;

		next unless $hdl;

		$genkei->{$i}{id}  = $hdl->[0];
		$genkei->{$i}{num} = $hdl->[1];

		# hyoso of children
		my $sql = "
			SELECT hyoso.id
			FROM   hyoso, genkei
			WHERE
				hyoso.genkei_id = genkei.id
				AND 
		";
		my $sql_w;
		my $n = 0;
		foreach my $h (@{$config->{$i}}){
			$sql_w .= " OR " if $n;
			$sql_w .= "genkei.name = '$h'";
			++$n;
		}
		$sql = $sql .= "( $sql_w )";
		$sql .= " AND NOT genkei_id = $genkei->{$i}{id}";
		
		my $hdl = mysql_exec->select($sql,1)->hundle;
		while (my $h = $hdl->fetch){
			push @{$hyoso->{$i}}, $h->[0];
		}

		# freq of children
		my $hdl = mysql_exec->select("
			SELECT sum(genkei.num)
			FROM   genkei
			WHERE  ( $sql_w ) AND NOT genkei.id = $genkei->{$i}{id}
		",1)->hundle->fetch;
		if ($hdl){
			$genkei->{$i}{add} = $hdl->[0];
		} else {
			$genkei->{$i}{add} = 0;
		}

	}
	
	# exec
	foreach my $i (keys %{$config}){
		# hyoso
		my $sql = '';
		$sql .= "
			UPDATE hyoso
			SET    genkei_id = $genkei->{$i}{id}
			WHERE 
		";
		my $n = 0;
		foreach my $h (@{$hyoso->{$i}}){
			$sql .= " OR " if $n;
			$sql .= "id = $h";
			++$n;
		}
		next unless $n;
		mysql_exec->do($sql,1);

		# genkei 1
		$sql = '';
		$sql .= "DELETE FROM genkei\nWHERE ";
		my $n = 0;
		foreach my $h (@{$config->{$i}}){
			$sql .= " OR " if $n;
			$sql .= "( name = '$h' AND NOT id = $genkei->{$i}{id} )";
			++$n;
		}
		mysql_exec->do($sql,1);

		# genkei 2
		my $new_num = $genkei->{$i}{num} + $genkei->{$i}{add};
		$sql = '';
		$sql .= "
			UPDATE genkei
			SET    num = $new_num
			WHERE  id = $genkei->{$i}{id}
		";
		mysql_exec->do($sql,1);
		
		# df
		foreach my $u (@avail){
			my $df = 0;
			if ($u eq 'bun'){
				$df = mysql_exec->select("
					SELECT COUNT(DISTINCT bun_idt)
					FROM hyosobun, hyoso
					WHERE
						hyosobun.bun_idt
						AND hyosobun.hyoso_id = hyoso.id
						AND hyoso.genkei_id = $genkei->{$i}{id}
				",1)->hundle->fetch;
				$df = $df->[0] if $df;
			} else {
				$df = mysql_exec->select("
					SELECT COUNT(DISTINCT tid)
					FROM hyosobun, $u"."_hb, hyoso
					WHERE
						hyosobun.id = $u"."_hb.hyosobun_id
						AND hyosobun.hyoso_id = hyoso.id
						AND hyoso.genkei_id = $genkei->{$i}{id}
				",1)->hundle->fetch;
				$df = $df->[0] if $df;
			}
			
			mysql_exec->do("
				UPDATE df_$u
				SET f = $df
				WHERE genkei_id = $genkei->{$i}{id}
			",1);
		}
	}

	$mw->messageBox(
		-message => '処理が完了しました。抽出語リストをご確認ください。',
		-icon    => 'info',
		-type    => 'ok',
		-title   => 'KH Coder'
	);
	$::main_gui->inner->refresh;

	return 1;
}

1;
