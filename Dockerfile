FROM node:16.15.0

RUN mkdir -p /app
WORKDIR /app

COPY . /app

# Pre-Build (download all node modules, http-server, etc)
RUN wget https://codejudge-starter-repo-artifacts.s3.ap-south-1.amazonaws.com/web-micro-project/javascript/react/18.1/npm/pre-build.sh
RUN chmod 775 ./pre-build.sh
RUN sh ./pre-build.sh

# Add extra docker commands here (if any)...

# Build the app (ng build --prod)
RUN wget https://codejudge-starter-repo-artifacts.s3.ap-south-1.amazonaws.com/web-micro-project/javascript/react/18.1/npm/build-v3.sh
RUN chmod 775 ./build-v3.sh
RUN sh ./build-v3.sh

# Add extra docker commands here (if any)...

WORKDIR /app/build

# Run the app
RUN wget https://codejudge-starter-repo-artifacts.s3.ap-south-1.amazonaws.com/web-micro-project/javascript/common/run.sh
RUN chmod 775 ./run.sh
CMD ./run.sh
