import csv

from joblib import dump,load
from sklearn.svm import SVC
from sklearn.model_selection import train_test_split

tolerance_percent = 97

try:
    model = load('training_model.joblib')
    # predictions = model.predict([[60000.0, 25000.0]])
    # print(predictions)
except Exception as e:
    # print(e)
    with open('training_data.csv') as f:
        reader = csv.reader(f)
        next(reader)
        data = []

        for row in reader:
            data.append({
                'parameters': [float(cell) for cell in row[:2]],
                'results': 'Sure' if row[2] == '0' else 'Maybe'
            })
    parameters = [row['parameters'] for row in data]
    results = [row['results'] for row in data]

    X_training,X_testing,y_training,y_testing = train_test_split(parameters,results,test_size=0.2)
    model = SVC()
    model.fit(X_training, y_training)
    predictions = model.predict(X_testing)

    correct = (y_testing == predictions).sum()
    incorrect = (y_testing != predictions).sum()

    total = len(predictions)

    accuracy = 100 * correct / total
    if(accuracy > tolerance_percent):
        dump(model, 'training_model.joblib')

    print(f"Results for model {type(model).__name__}")
    print(f"Correct: {correct}")
    print(f"InCorrect: {incorrect}")
    print(f"Accuracy: {accuracy:.2f}%")



