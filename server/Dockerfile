FROM node:22-alpine

WORKDIR /app

COPY package.json ./
COPY core.js ./
COPY standalone_server.js ./

ENV PORT=3000
ENV HOST=0.0.0.0
ENV NODE_ENV=production

EXPOSE 3000

CMD ["node", "standalone_server.js"]
