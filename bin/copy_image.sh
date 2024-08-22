#!/bin/bash

VERSION="1.0.0"

###############################################################################
# This script uses skopeo to copy a docker image from one repository to
# another.  The primary intent is to copy the image from a public repository
# to a private repository.
###############################################################################
# Expected environment variables:
#
# SOURCE_IMAGE - The image to copy to to another location.  Example:
#                paradyme-docker-local.jfrog.io/appetizer:dev
# SOURCE_INSECURE - Set this to 1 of the source repository is in an insecure
#                docker registry.  Set it to 0 or leave it unset if the
#                docker registry is secure.
#
# DESTINATION_IMAGE - The image to copy to to another location.  Example:
#                paradyme-docker-local.jfrog.io/appetizer:dev
# DESTINATION_INSECURE - Set this to 1 of the destination repository is in
#                an insecure docker registry.  Set it to 0 or leave it unset
#                if the docker registry is secure.
#
# When the source repository requires authentication to access, configure
# these values.  Otherwise do not set them.
#
# SOURCE_USERNAME - The username to supply for credentialed access to the
#                repository.  `anthony-zawacki` is an example.
# SOURCE_PASSWORD - The password to supply for credentialed access to the
#                repository.  An artifactory API_KEY for example.
#
# When the destination repository requires authentication to access, configure
# these values.  Otherwise do not set them.
#
# DESTINATION_USERNAME - The username to supply for credentialed access to the
#                repository.  `anthony-zawacki` is an example.
# DESTINATION_PASSWORD - The password to supply for credentialed access to the
#                repository.  The output of:
#                `aws ecr get-login-password --region us-east-2` for example.
#
# If the destination repository does not exist, the copy_image.sh script will
# create the repository automatically.  In cases where the newly created
# repository should have a mutable image (perhaps always pushing to a `latest`
# tag in a development environment), it is possible to configure the
# repository to allow mutability by configuring this environment variable.
# Otherwise, do not set it.
#
#
###############################################################################

ensure_skopeo() {
	skopeo=$(command -v skopeo)
	if [[ "$skopeo" == "" ]]; then
		echo "The required executable, skopeo, was not found."
		echo "Please install it and ensure it is in the path."
		return 1
	fi

	return 0
}

usage() {
	local msg="${1}"; shift;

	cat <<EOF
  $msg:

  $0 [options]

  -src-image <img> (SOURCE_IMAGE) The name of the image to copy to another
       registry.
  -src-username <username> (SOURCE_USERNAME) Optional parameter in cases where
       the source registry requires authentication.  Use this username for the
       credentials.
  -src-password <password> (SOURCE_PASSWORD) Optional parameter in cases where
       the source registry requires authentication.  Use this password for the
       credentials.
  -src-insecure (SOURCE_INSECURE=1) Optional parameter indicates that the
       source registry is not a secured registry and that tls validation
       should be disabled for the processing of the image.  The default is
       to assume that the source registry is secured.
  +src-insecure (SOURCE_INSECURE=0) Optional parameter explicitly indicating
       that the source registry is secure and TLS must be used to access the
       registry.

  -dest-image <img> (DESTINATION_IMAGE) The name of the image to to use in the
       destination registry.
  -dest-username <username> (DESTINATION_USERNAME) Optional parameter in cases
       where the destination registry requires authentication.  Use this
       username for the credentials.
  -dest-password <password> (DESTINATION_PASSWORD) Optional parameter in cases
       where the destination registry requires authentication.  Use this
       password for the credentials.
  -dest-insecure (DESTINATION_INSECURE=1) Optional parameter indicates that the
       destination registry is not a secured registry and that tls validation
       should be disabled for the processing of the image.  The default is
       to assume that the destination registry is secured.
  +dest-insecure (DESTINATION_INSECURE=0) Optional parameter explicitly
       indicating that the destination registry is secure and TLS must be
       used to access the registry.
  -dest-mutable (DESTINATION_MUTABLE=1) Optional parameter indicates that if
       creating the ECR repository is required, create it allowing mutable
       images.
  +dest-mutable (DESTNATION_MUTABLE=0) Optional parameter explicitly
       indicating that if creating the ECR repository is required, create it
       with immutable images.

EOF

	exit 1
}

parse_commandline() {
	local key
	local positional=()

	while [[ $# -gt 0 ]]; do
		key="$1"; shift

		case "$key" in
		-src-image)
			SOURCE_IMAGE="$1"; shift
			;;
		-src-username)
			SOURCE_USERNAME="$1"; shift
			;;
		-src-password)
			SOURCE_PASSWORD="$1"; shift
			;;
		-src-insecure)
			SOURCE_INSECURE=1
			;;
		+src-insecure)
			SOURCE_INSECURE=0
			;;
		-dest-image)
			DESTINATION_IMAGE="$1"; shift
			;;
		-dest-username)
			DESTINATION_USERNAME="$1"; shift
			;;
		-dest-password)
			DESTINATION_PASSWORD="$1"; shift
			;;
		-dest-insecure)
			DESTINATION_INSECURE=1
			;;
		+dest-insecure)
			DESTINATION_INSECURE=0
			;;
		-dest-mutable)
			DESTINATION_MUTABLE=1
			;;
		+dest-mutable)
			DESTINATION_MUTABLE=0
			;;
		*)
			positional+=("$key")
			;;
		esac
	done

	if [[ ${#positional[@]} -gt 0 ]]; then
		usage "Unrecognized parameters: ${positional[*]}"
	fi
}

ensure_parameters() {
	if [[ "$SOURCE_IMAGE" == "" ]]; then
		usage "Must specify SOURCE_IMAGE"
	fi

	if [[ "$DESTINATION_IMAGE" == "" ]]; then
		usage "Must specify DESTINATION_IMAGE"
	fi

	if [[ "$SOURCE_USERNAME" != "" || "$SOURCE_PASSWORD" != "" ]]; then
		if [[ "$SOURCE_USERNAME" == "" || "$SOURCE_PASSWORD" == "" ]]; then
			usage "Must specify both the SOURCE_USERNAME and SOURCE_PASSWORD."
		fi
	fi

	if [[ "$DESTINATION_USERNAME" != "" || "$DESTINATION_PASSWORD" != "" ]]; then
		if [[ "$DESTINATION_USERNAME" == "" || "$DESTINATION_PASSWORD" == "" ]]; then
			usage "Must specify both the DESTINATION_USERNAME and DESTINATION_PASSWORD."
		fi
	fi

	return 0
}

image_exists() {
	declare src_creds="$SOURCE_USERNAME:$SOURCE_PASSWORD"
	declare command=(skopeo inspect --insecure-policy)

	if [[ "$SOURCE_USERNAME" != "" ]]; then
#		command+=(--src-creds "$src_creds")
		command+=(--creds "$src_creds")
	else
#		command+=(--src-no-creds)
		command+=(--no-creds)
	fi

# 	if [[ "$SOURCE_INSECURE" == "1" ]]; then
# 		command+=(--src-tls-verify=false)
# 	else
# 		command+=(--src-tls-verify=true)
# 	fi

	command+=("docker://$SOURCE_IMAGE")

	${command[@]} > /dev/null 2>&1
        status=$?
	echo "* source_image_exists() status=$status"
	# return 0 if it does, 1 if not
	return $?
}

destination_image_exists() {
	declare dst_creds="$DESTINATION_USERNAME:$DESTINATION_PASSWORD"
	declare command=(skopeo inspect --insecure-policy)

	if [[ "$DESTINATION_USERNAME" != "" ]]; then
#		command+=(--dest-creds "$dst_creds")
		command+=(--creds "$dst_creds")
	else
#		command+=(--dest-no-creds)
		command+=(--no-creds)
	fi

#	if [[ "$DESTINATION_INSECURE" == "1" ]]; then
#		command+=(--dest-tls-verify=false)
#	else
#		command+=(--dest-tls-verify=true)
#	fi

	command+=("docker://$DESTINATION_IMAGE")

	${command[@]} > /dev/null 2>&1
	status=$?
	echo "* destination_image_exists() status=$status"
	# return 0 if it does, 1 if not
	return ${status}
}

copy_image() {
	declare src_creds="$SOURCE_USERNAME:$SOURCE_PASSWORD"
	declare dest_creds="$DESTINATION_USERNAME:$DESTINATION_PASSWORD"
	declare command=(skopeo copy --insecure-policy)

	if [[ "$SOURCE_USERNAME" != "" ]]; then
		command+=(--src-creds "$src_creds")
	else
		command+=(--src-no-creds)
	fi

	if [[ "$SOURCE_INSECURE" == "1" ]]; then
		command+=(--src-tls-verify=false)
	else
		command+=(--src-tls-verify=true)
	fi

	if [[ "$DESTINATION_USERNAME" != "" ]]; then
		command+=(--dest-creds "$dest_creds")
	else
		command+=(--dest-no-creds)
	fi

	if [[ "$DESTINATION_INSECURE" == "1" ]]; then
		command+=(--dest-tls-verify=false)
	else
		command+=(--dest-tls-verify=true)
	fi

	command+=("docker://$SOURCE_IMAGE" "docker://$DESTINATION_IMAGE")

    if [[ "$DESTINATION_IMAGE" == *.dkr.ecr.*.amazonaws.com/* ]]; then
        echo "ECR registry detected, ensuring repository."
        declare repository="${DESTINATION_IMAGE##*.amazonaws.com/}"
        repository="${repository%%:*}"
        declare region="${DESTINATION_IMAGE%%.amazonaws.com/*}"
        region="${region##*.}"
        export AWS_PAGER=""
        if ! aws ecr describe-repositories \
                 --region "$region" \
                 --output "json" \
                 --repository-names "$repository" \
                 > /dev/null 2>&1; then
            local mutability="IMMUTABLE"
            if [ "$DESTINATION_MUTABLE" == "1" ]; then
                mutability="MUTABLE"
            fi
            echo "creating repository $repository."
            aws ecr create-repository \
                --image-tag-mutability "$mutability" \
                --image-scanning-configuration "scanOnPush=true" \
                --encryption-configuration "encryptionType=KMS" \
                --repository-name "$repository" \
                --region "$region" \
                > /dev/null 2>&1 || return $?
        else
            echo "repository $repository exists."
        fi
    fi

	echo "Copying $SOURCE_IMAGE"
	echo "to $DESTINATION_IMAGE"

	${command[@]}
}


ensure_image() {
	( image_exists && ! destination_image_exists ) || copy_image
}

main() {
	ensure_skopeo && \
	parse_commandline "$@" && \
	ensure_parameters && \
	ensure_image && \
	echo "Done"
}

return 0 > /dev/null 2>&1 || main "$@"

