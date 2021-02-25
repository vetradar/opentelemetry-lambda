NAME=opentelemetry-lambda-extension
REGIONS=${AWS_DEFAULT_REGION}
GIT_HASH=$(shell git rev-parse --short HEAD)
S3_BUCKET=${S3_DEPLOYMENT_BUCKET}
AWS_ACCOUNT=$(shell aws sts get-caller-identity | jq -r ".Account")
VERSION=$(shell aws lambda list-layers --output json | jq -r ".Layers[] | select(.LayerName==\"$(NAME)\").LatestMatchingVersion.Version")



build:
	GOOS=linux GOARCH=amd64 go build -o bin/extensions/$(NAME) *.go
	chmod +x bin/extensions/$(NAME)

publish:
	rm -f ./*.zip
	chmod +x bin/extensions/$(NAME)
	cd bin && zip -r $(GIT_HASH).zip extensions/
	for region in $(REGIONS); do \
		aws --region $$region s3 cp ./bin/$(GIT_HASH).zip s3://$(S3_DEPLOYMENT_BUCKET)-$$region/; \
		aws lambda publish-layer-version \
			--layer-name "$(NAME)" \
			--description "OpenTelemetry Lambda Extension" \
			--region $$region \
			--content S3Bucket=$(S3_DEPLOYMENT_BUCKET)-$$region,S3Key=$(GIT_HASH).zip \
			--compatible-runtimes nodejs12.x nodejs14.x python3.6 python3.7 python3.8 ruby2.5 ruby2.7 java8 java8.al2 java11 dotnetcore3.1 provided.al2 \
			--no-cli-pager \
			--output text ; \
	done

permissions:
	for region in $(REGIONS); do \
		aws lambda add-layer-version-permission \
			--layer-name $(NAME)  \
			--principal $(AWS_ACCOUNT)  \
			--action lambda:GetLayerVersion \
			--version-number $(VERSION) \
			--statement-id xaccount \
			--region $$region \
			--no-cli-pager \
			--output text ; \
	done

build-OpenTelemetryExtensionLayer:
	GOOS=linux GOARCH=amd64 go build -o $(ARTIFACTS_DIR)/extensions/$(NAME) *.go
	chmod +x $(ARTIFACTS_DIR)/extensions/$(NAME)

run-OpenTelemetryExtensionLayer:
	go run $(NAME)/*.go

test:
	# TODO
