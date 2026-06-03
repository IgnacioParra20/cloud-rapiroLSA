import json
import time
from awscrt import mqtt
from awsiot import mqtt_connection_builder


AWS_IOT_ENDPOINT = "a2mndyhmsh25ki-ats.iot.us-east-2.amazonaws.com"
CLIENT_ID = "rapiro-lsa-python-client"

TOPIC = "rapiro/lsa/keypoints"

PATH_TO_CERTIFICATE = "security/rapiro-certificate.pem.crt"
PATH_TO_PRIVATE_KEY = "security/rapiro-private.pem.key"
PATH_TO_AMAZON_ROOT_CA_1 = "security/AmazonRootCA1.pem"


def main():
    print("Conectando a AWS IoT Core...")

    mqtt_connection = mqtt_connection_builder.mtls_from_path(
        endpoint=AWS_IOT_ENDPOINT,
        cert_filepath=PATH_TO_CERTIFICATE,
        pri_key_filepath=PATH_TO_PRIVATE_KEY,
        ca_filepath=PATH_TO_AMAZON_ROOT_CA_1,
        client_id=CLIENT_ID,
        clean_session=False,
        keep_alive_secs=30,
    )

    connect_future = mqtt_connection.connect()
    connect_future.result()
    print("Conectado correctamente.")

    payload = {
        "SessionId": "python-iot-test-001",
        "DetectedSign": "Hola",
        "Confidence": 0.98,
        "Source": "Python Local"
    }

    print("Publicando mensaje:")
    print(json.dumps(payload, indent=2))

    publish_future, packet_id = mqtt_connection.publish(
        topic=TOPIC,
        payload=json.dumps(payload),
        qos=mqtt.QoS.AT_LEAST_ONCE,
    )

    publish_future.result()
    print(f"Mensaje publicado en topic: {TOPIC}")

    time.sleep(2)

    print("Desconectando...")
    disconnect_future = mqtt_connection.disconnect()
    disconnect_future.result()
    print("Desconectado.")


if __name__ == "__main__":
    main()