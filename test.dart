#import("lib/sqlite.dart", prefix:"sqlite");

main() {
	var c = new sqlite.Connection("/tmp/test.db");
	try {
		print(c.first("SELECT ?+2, UPPER(?)", [3, "Hello"]).asMap());
		
		print("My blog");
		var count = c.execute("SELECT * FROM posts", callback: (row) {
			print("[${row.title}]: ${row['body']} : ${row[0]}");
		});
		print("${count} posts total.");
	} finally {
		c.close();
	}
}
