FROM node:lts
USER root
RUN mkdir -p /app
RUN chown -R node:node /app
USER node
WORKDIR /app
COPY package.json yarn.lock /app/
RUN yarn install
COPY hardhat.config.js /app/
COPY contracts /app/contracts
COPY scripts /app/scripts