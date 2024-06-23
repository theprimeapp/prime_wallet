from rest_framework import serializers
from .models import Predictor

class PredictorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Predictor
        fields = ['isSafe']