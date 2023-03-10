#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cJSON.h"

char *g_index = NULL;

static void manipulate_eth(cJSON *eth)
{
	cJSON_DeleteItemFromObjectCaseSensitive(eth, "eth_eth_addr");
	cJSON_DeleteItemFromObjectCaseSensitive(eth, "eth_eth_addr_resolved");
	cJSON_DeleteItemFromObjectCaseSensitive(eth, "eth_eth_addr_oui");
	cJSON_DeleteItemFromObjectCaseSensitive(eth, "eth_eth_addr_oui_resolved");
	cJSON_DeleteItemFromObjectCaseSensitive(eth, "eth_eth_lg");
	cJSON_DeleteItemFromObjectCaseSensitive(eth, "eth_eth_ig");
	/* Who thought this was a good idea?? */
	cJSON_DeleteItemFromObjectCaseSensitive(eth, "eth_eth_addr");
	cJSON_DeleteItemFromObjectCaseSensitive(eth, "eth_eth_addr_resolved");
	cJSON_DeleteItemFromObjectCaseSensitive(eth, "eth_eth_addr_oui");
	cJSON_DeleteItemFromObjectCaseSensitive(eth, "eth_eth_addr_oui_resolved");
	cJSON_DeleteItemFromObjectCaseSensitive(eth, "eth_eth_lg");
	cJSON_DeleteItemFromObjectCaseSensitive(eth, "eth_eth_ig");
}

static void manipulate_layers(cJSON *layers)
{

/*
	cJSON *frame = cJSON_GetObjectItemCaseSensitive(layers, "frame");
	if(frame) { manipulate_frame(frame); }
*/

	cJSON *eth = cJSON_GetObjectItemCaseSensitive(layers, "eth");
	if(eth) { manipulate_eth(eth); }

/*
	cJSON *ip = cJSON_GetObjectItemCaseSensitive(layers, "ip");
	if(ip) { manipulate_ip(ip); }
	cJSON *udp = cJSON_GetObjectItemCaseSensitive(layers, "udp");
	if(udp) { manipulate_udp(udp); }
	cJSON *data = cJSON_GetObjectItemCaseSensitive(layers, "data");
	if(data) { manipulate_data(data); }
*/

	/* Delete the data object */
	cJSON_DeleteItemFromObjectCaseSensitive(layers, "data");
}

/*
static void manipulate_timestamp(cJSON *root)
{
	char *new_ts = NULL;

	cJSON_DeleteItemFromObjectCaseSensitive(root, "timestamp");
	cJSON *layers = cJSON_GetObjectItemCaseSensitive(root, "layers");
	if(layers) {
		cJSON *frame = cJSON_GetObjectItemCaseSensitive(layers, "frame");
		if(frame) {
			cJSON *frame_frame_time_epoch = cJSON_GetObjectItemCaseSensitive(frame, "frame_frame_time_epoch");
			if(frame_frame_time_epoch && cJSON_IsString(frame_frame_time_epoch)) {
				new_ts = cJSON_GetStringValue(frame_frame_time_epoch);
			}
		}
	}

	if(new_ts) { cJSON_AddStringToObject(root, "packet_capture_timestamp", new_ts); }
}
*/

static void handle_packet(char *line)
{
	/*printf("%s\n", line);*/
	cJSON *root = cJSON_Parse(line);
	if(!root) { return; }
	/*manipulate_timestamp(root);*/
	cJSON *layers = cJSON_GetObjectItemCaseSensitive(root, "layers");
	if(layers) { manipulate_layers(layers); }
	char *minjson = cJSON_Print(root);
	cJSON_Minify(minjson);
	printf("%s\n", minjson);
	free(minjson);
	cJSON_Delete(root);
}

static void handle_index(char *line)
{
	/*printf("%s\n", line);*/
	cJSON *root = cJSON_Parse(line);
	/*cJSON_DeleteItemFromObject(root, "index");*/
	cJSON *index = cJSON_GetObjectItemCaseSensitive(root, "index");
	if(index) {
		cJSON_DeleteItemFromObject(index, "_index");
		cJSON_DeleteItemFromObject(index, "_type");
		if(g_index) {
			cJSON_AddStringToObject(index, "_index", g_index);
			cJSON_AddStringToObject(index, "_type", "_doc");
		}
	}
	char *minjson = cJSON_Print(root);
	cJSON_Minify(minjson);
	printf("%s\n", minjson);
	free(minjson);
	cJSON_Delete(root);
}

void handle_ndjson(char *line)
{
	if(strncmp(line, "{\"index\":{", 10) == 0) {
		handle_index(line);
	} else {
		handle_packet(line);
	}
}

void initialize(void)
{
	/* Setting INDEX is optional */
	g_index = getenv("INDEX");
}
