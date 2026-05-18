import 'https://esm.sh/zone.js@0.14.10?bundle';
import { bootstrapApplication } from 'https://esm.sh/@angular/platform-browser@17.3.12?bundle';
import { Component, signal } from 'https://esm.sh/@angular/core@17.3.12?bundle';
import { NgFor, NgIf, JsonPipe } from 'https://esm.sh/@angular/common@17.3.12?bundle';
import { FormsModule } from 'https://esm.sh/@angular/forms@17.3.12?bundle';

function nuiPost(name, data = {}) {
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
}

const AppComponent = Component({
  selector: 'app-root',
  standalone: true,
  imports: [NgFor, NgIf, JsonPipe, FormsModule],
  template: `
    <main id="app" [class.hidden]="!isOpen()">
      <section class="sidebar">
        <h1>Character Selection</h1>
        <div class="cards">
          <article
            class="card"
            [class.active]="active()?.cid === c.cid"
            *ngFor="let c of chars()"
            (click)="selectCard(c)">
            <div class="name">{{ c.name || 'Unnamed' }}</div>
            <div class="meta">{{ c.job || 'Unemployed' }}</div>
          </article>
        </div>
      </section>

      <section class="details">
        <h2>{{ active()?.name || 'Select a character' }}</h2>
        <pre *ngIf="active() as current">{{ current | json }}</pre>

        <div class="actions">
          <button (click)="play()">Play</button>
          <button (click)="toggleDelete()">Delete</button>
          <button (click)="create()">Create</button>
        </div>

        <div class="token-wrap" *ngIf="deleteMode()">
          <label>Type server token to delete:</label>
          <input [(ngModel)]="deleteToken" placeholder="Token" />
          <button (click)="confirmDelete()">Confirm Delete</button>
        </div>
      </section>
    </main>
  `,
})(class {
  isOpen = signal(false);
  chars = signal([]);
  active = signal(null);
  deleteMode = signal(false);
  deleteToken = '';

  constructor() {
    window.addEventListener('message', (e) => {
      const msg = e.data;
      if (msg.action === 'open') {
        this.chars.set(msg.payload?.characters || []);
        this.active.set((msg.payload?.characters || [])[0] || null);
        this.deleteMode.set(false);
        this.deleteToken = '';
        this.isOpen.set(true);
      }
    });
  }

  selectCard(char) {
    this.active.set(char);
    this.deleteMode.set(false);
  }

  play() {
    const current = this.active();
    if (current) nuiPost('selectCharacter', { cid: current.cid });
  }

  create() {
    nuiPost('createCharacter');
  }

  toggleDelete() {
    this.deleteMode.set(!this.deleteMode());
  }

  confirmDelete() {
    const current = this.active();
    if (!current || !this.deleteToken.trim()) return;
    nuiPost('deleteCharacter', { cid: current.cid, token: this.deleteToken.trim() });
  }
});

bootstrapApplication(AppComponent).catch((err) => console.error(err));
