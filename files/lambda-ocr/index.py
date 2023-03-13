import boto3
from os import environ, path, makedirs
import json
from PyPDF2 import PdfReader
from opensearchpy import OpenSearch, RequestsHttpConnection, AWSV4SignerAuth
import logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


sqs = boto3.client('sqs')
s3 = boto3.resource('s3')
comprehend = boto3.client('comprehend')

host = environ.get('OPENSEARCH_DOMAIN')
port = 443
service = 'es'
logger.info('Getting Credentials')
credentials = boto3.Session().get_credentials()
auth = AWSV4SignerAuth(credentials, environ.get('AWS_REGION'), service)
logger.debug('Got Credentials')
index_name = 'document-index'

# Create the client with SSL/TLS enabled, but hostname verification disabled.
logger.info('Creating OpenSearch Client')
os_client = OpenSearch(
		hosts = [{'host': host, 'port': port}],
		http_auth = auth,
		use_ssl = True,
		verify_certs = True,
		connection_class = RequestsHttpConnection,
		pool_maxsize = 20
)
logger.debug('Made Connection')

def download_object(bucket, key, local_object_path):
	logger.info('Downloading Document')
	s3.meta.client.download_file(bucket, key, local_object_path)
	logger.debug('Downloaded Document')

def get_entities(text):
	logger.info('Getting Entities')
	entities = []
	response = comprehend.detect_entities(
		Text=text,
		LanguageCode='en'
		)
	for entity in response['Entities']:
		entities.append(entity['Text'])
	logger.debug('Got Entities')
	return list(set(entities))

def get_key_phrases(text):
	logger.info('Getting Key Phrases')
	phrases = []
	response = comprehend.detect_key_phrases(
		Text=text,
		LanguageCode='en'
		)
	for phrase in response['KeyPhrases']:
		phrases.append(phrase['Text'])
	logger.info('Got Key Phrases')
	return list(set(phrases))
	
def upload_document_to_opensearch(document_location, local_object_path):
	logger.info('Extracting Document Text')
	bulk_documents = ''
	reader = PdfReader(local_object_path)
	for i,page in enumerate(reader.pages):
		doc_id = '{}_page_{}'.format(document_location, i)
		text = page.extract_text()
		entities = get_entities(text)
		phrases = get_key_phrases(text)
		bulk_1 = json.dumps({
			"index": {
				"_index": index_name, 
				"_id": doc_id
			}
		})
		bulk_2 = json.dumps({
			'text': {
				doc_id: text
			},
			'entities' : entities,
			'phrases': phrases
		})
		bulk_documents = bulk_documents + '{}\n{}\n'.format(bulk_1, bulk_2)
	logger.debug('Extracted Document Text')

	logger.info('Uploading Documents')
	response = os_client.bulk(bulk_documents)
	logger.debug('Uploaded Documents')
	logger.debug(response)
	

def lambda_handler(event, context):
	logger.debug(json.dumps(event))
	
	for e in  event['Records']:
		if 'AWS_EXECUTION_ENV' in environ:
			local_object_path = '/tmp'
		else:
			local_object_path = './tmp'
		
		message_body = json.loads(e['body'])['Records'][0]
		bucket_name = message_body['s3']['bucket']['name']
		document_name = message_body['s3']['object']['key']

		local_object_path = '{}/{}'.format(local_object_path, document_name)
		if not path.exists(path.dirname(local_object_path)):
			makedirs(path.dirname(local_object_path))

		download_object(bucket=bucket_name, key=document_name, local_object_path=local_object_path)
		upload_document_to_opensearch(document_location='s3://{}/{}'.format(bucket_name, document_name), local_object_path=local_object_path)
		