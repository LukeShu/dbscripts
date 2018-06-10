load ../lib/common

@test "commands display usage message by default" {
	for cmd in db-move db-remove db-repo-add db-repo-remove db-import-pkg; do
		echo Testing $cmd
		run $cmd
		(( $status != 0 ))
		[[ $output == *'usage: '* ]]
	done
}
