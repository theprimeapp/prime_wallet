from django.http import JsonResponse
import requests
from .models import Predictor
from .serializers import PredictorSerializer
import joblib
from pathlib import Path
from rest_framework.decorators import api_view


@api_view(['GET'])
def predict_contract(request):
    try:
        query_params = request.query_params

        if(len(query_params) == 0):
            return JsonResponse({'error': 'Please provide the query parameters'}, status=400)
        
        contract_addr = query_params.get('contract_addr')
        if(contract_addr is None):
            return JsonResponse({'error': 'Please provide the contract_addr'}, status=400)
        
        token_details = get_contract_details(contract_addr)
        model = joblib.load('training_model.joblib')
        predictions = model.predict([token_details])
        data = {'isSafe': predictions[0] == 'Sure' }
        serializier = PredictorSerializer(data)
        return JsonResponse(serializier.data)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

def get_contract_details(contract_addr):
    request = requests.get(f'https://api.dexscreener.com/latest/dex/tokens/{contract_addr}')
    response = request.json()
    result = response['pairs'][0]
    return result['liquidity']['usd'],result['fdv']

