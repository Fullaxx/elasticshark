#ifdef USE_GETLINE
#define _GNU_SOURCE
#else
#define _XOPEN_SOURCE 700
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void initialize(void);
void handle_ndjson(char *line);

static void chomp(char *buf)
{
	size_t l;
	if(!buf) { return; }
	l = strlen(buf)-1;
	if(l >= 0) {
		if(buf[l] == '\n') { buf[l] = '\0'; }
		if(buf[l] == '\r') { buf[l] = '\0'; }
	}
}

static void process_lines(FILE *input)
{
#ifdef USE_GETLINE
	size_t n;
	ssize_t bytes;
#else
	char *retval;
	char buf[8192];
	/* We cannot use fgets here b/c we have no idea how long these lines can be */
#endif

	char *line = NULL;

	while(!feof(input)) {
#ifdef USE_GETLINE
		n=0; bytes = getline(&line, &n, input);
		if(bytes < 0) { break; }
#else
		memset(&buf[0], 0, sizeof(buf));
		retval = fgets(buf, sizeof(buf), input);
		if(!retval) { break; }
		line = strdup(buf);
#endif

		chomp(line);
		handle_ndjson(line);
		free(line);
		line = NULL;
	}

	if(line) { free(line); }
}

static void process_file(char *filename)
{
	FILE *f = fopen(filename, "r");
	if(!f) {
		fprintf(stderr, "fopen(%s, r) failed! \n", filename);
		exit(1);
	}
	process_lines(f);
	fclose(f);
}

int main(int argc, char *argv[])
{
	initialize();

	if(argc == 1) {
		process_lines(stdin);
	} else {
		while(--argc > 0) { process_file(argv[argc]); }
	}

	return 0;
}
