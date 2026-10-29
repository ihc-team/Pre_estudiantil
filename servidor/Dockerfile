FROM node:24-alpine AS deps
WORKDIR /app

COPY package*.json ./
RUN npm ci

FROM node:24-alpine AS runner
WORKDIR /app

RUN apk add --no-cache openssl

ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY package*.json ./
COPY prisma ./prisma
COPY *.js ./

RUN npx prisma generate

RUN chown -R node:node /app
USER node

EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy && node servidor.js"]
