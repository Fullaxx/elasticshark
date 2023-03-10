#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cJSON.h"

void handle_ndjson(char *line)
{
	/* Ignore the elasticsearch commands */
	if(strncmp(line, "{\"timestamp\":", 13)) { return; }

	cJSON *root = cJSON_Parse(line);
	char *json = cJSON_Print(root);
	printf("%s\n", json);
	free(json);
	cJSON_Delete(root);

}

void initialize(void)
{

}
