FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
# El runtime corre como usuario sin privilegios (el user 'node' ya existe en la
# imagen oficial). NODE_ENV=production deja npm ci sin devDependencies.
COPY --from=build --chown=node:node /app/dist ./dist
USER node
EXPOSE 3000
CMD ["node","dist/main"]
