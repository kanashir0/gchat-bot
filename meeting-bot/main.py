from json import dumps,loads

from httplib2 import Http

def main(request):
    print("request",request.data)
    
    request_json=loads(request.data)
    webhook=None
    meeting_url=None

    if request_json and 'webhook' in request_json:
        webhook = request_json['webhook']
    if request_json and 'meeting_url' in request_json:
        meeting_url = request_json['meeting_url']
    
    if webhook is None or meeting_url is None:
        return "fail", 400

    """Hangouts Chat incoming webhook quickstart."""
    bot_message = {
        'text' : f' <users/all> nossa daily esta prestes a começar, bora moçada! {meeting_url}'}

    message_headers = {'Content-Type': 'application/json; charset=UTF-8'}

    http_obj = Http()

    response = http_obj.request(
        uri=webhook,
        method='POST',
        headers=message_headers,
        body=dumps(bot_message),
    )

    return "ok", 200