import { Injectable, OnModuleInit } from "@nestjs/common";
import * as argon2 from "argon2";
import { randomBytes } from "node:crypto";
@Injectable()
export class PasswordService implements OnModuleInit {
  private dummyHash!: string;
  readonly options = {
    type: argon2.argon2id,
    memoryCost: 65536,
    timeCost: 3,
    parallelism: 1,
  } as const;
  async onModuleInit() {
    this.dummyHash = await this.hash(randomBytes(32).toString("hex"));
  }
  hash(password: string) {
    return argon2.hash(password, this.options);
  }
  async verify(hash: string | undefined, password: string) {
    const valid = await argon2.verify(hash ?? this.dummyHash, password);
    return hash !== undefined && valid;
  }
}
