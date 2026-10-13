# ---- Stage 1: builder - install production dependencies ----
FROM node:22.22.2-alpine3.22 AS builder

WORKDIR /opt/app

COPY app/package.json ./
RUN npm install --omit=dev && npm cache clean --force

COPY app/ ./

# ---- Stage 2: runtime - small image, runs as non-root ----
FROM node:22.22.2-alpine3.22


ENV NODE_ENV=production \
    PORT=3000

WORKDIR /opt/app

COPY --from=builder /opt/app ./

# Built-in "node" user (uid 1000) - never root.
USER 1000:1000

EXPOSE 3000

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]
