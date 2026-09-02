# The Meridian Post semantic layer — Cube.js API server for Cloud Run.
# Same recipe as the spotistats cubejs service: node:22-slim, production
# dependencies installed from the lock file, data model + config copied in,
# cubejs-server listening on :4000.
#
# No Cube Store: the data model defines no pre-aggregations and the
# cache/queue driver runs in-process memory (CUBEJS_CACHE_AND_QUEUE_DRIVER),
# so there is nothing for Cube Store to do.
FROM node:22-slim

WORKDIR /usr/src/app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY model/ ./model/
COPY cube.js ./cube.js

EXPOSE 4000

CMD [ "npm", "start" ]