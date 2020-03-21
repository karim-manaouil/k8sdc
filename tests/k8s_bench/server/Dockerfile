FROM python:3-alpine

RUN mkdir -p /usr/src/server
WORKDIR /usr/src/server

COPY . /usr/src/server
RUN pip install --no-cache-dir -r requirements.txt


# Expose the Flask port
EXPOSE 5000

CMD [ "python", "./server.py" ]
