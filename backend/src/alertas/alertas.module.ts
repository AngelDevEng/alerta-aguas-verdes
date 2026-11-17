import { Module } from '@nestjs/common';
import { RealtimeModule } from '../realtime/realtime.module';
import { AlertasController } from './alertas.controller';
import { AlertasService } from './alertas.service';

@Module({
  imports: [RealtimeModule],
  controllers: [AlertasController],
  providers: [AlertasService],
})
export class AlertasModule {}