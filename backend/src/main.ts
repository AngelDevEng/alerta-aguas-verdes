import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.use(helmet());
  app.enableCors({ origin: process.env.CORS_ORIGIN ?? '*' });
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));

  const doc = new DocumentBuilder()
    .setTitle('Alerta Aguas Verdes API')
    .setDescription('Gestión de incidencias, unidades de serenazgo y evidencias')
    .setVersion('0.1.0')
    .build();
  SwaggerModule.setup('api/docs', app, SwaggerModule.createDocument(app, doc));

  await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
}
bootstrap();
