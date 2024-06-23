from django.db import models

class Predictor(models.Model):
    isSafe = models.BooleanField(default=False)

    def __str__(self):
        return self.isSafe