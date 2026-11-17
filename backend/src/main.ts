import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { createHmac } from 'crypto';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  // Render envia SIGTERM al redeployar esta instancia: cerrar el pool de
  // TypeORM y las peticiones en curso en vez de abortarlas.
  app.enableShutdownHooks();
  app.getHttpAdapter().getInstance().set('trust proxy', 1);
  app.use(helmet());

  // Registro temporal de la IP del cliente (HMAC truncado, nunca la IP completa)
  // para validar que trust proxy resuelve la IP real detras del balanceador de
  // Render. Requiere IP_LOG_SECRET en entorno. Eliminar este middleware con un
  // commit separado tras confirmar en produccion.
  const ipLogSecret = process.env.IP_LOG_SECRET;
  if (ipLogSecret) {
    app.use((req, res, next) => {
      const ip = req.ip ?? 'desconocida';
      const ipHmac = createHmac('sha256', ipLogSecret)
        .update(ip)
        .digest('hex')
        .slice(0, 16);
      console.log(`[IP] ${req.method} ${req.url} ip_hmac=${ipHmac}`);
      next();
    });
  }

  // '*' solo es aceptable mientras no exista el frontend. En produccion se fija
  // CORS_ORIGIN al dominio del cliente: la API expone datos de ubicacion y evidencias.
  const origen = process.env.CORS_ORIGIN ?? '*';
  if (origen === '*' && process.env.NODE_ENV === 'production') {
    console.warn('[AVISO] CORS_ORIGIN="*" en produccion. Define el dominio del frontend.');
  }
  app.enableCors({ origin: origen === '*' ? true : origen.split(',').map((s) => s.trim()) });

  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
  app.useGlobalFilters(new AllExceptionsFilter());

  const doc = new DocumentBuilder()
    .setTitle('Alerta Aguas Verdes API')
    .setDescription('Gestion de incidencias, unidades de serenazgo, alertas SOS y evidencias')
    .setVersion('0.2.0')
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'bearer')
    .build();
  SwaggerModule.setup('api/docs', app, SwaggerModule.createDocument(app, doc), {
    swaggerOptions: { persistAuthorization: true },
  });

  await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
}
bootstrap();