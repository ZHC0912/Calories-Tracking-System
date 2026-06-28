"""add username and target_kcal_override to users

Revision ID: b1f2c3d4e5a6
Revises: aeafacf0960e
Create Date: 2026-06-28 00:00:00.000000

Both columns are nullable, so this is additive and safe on existing rows:
older accounts get NULL (username falls back to the email prefix; a NULL
target_kcal_override means the target is computed as before).
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b1f2c3d4e5a6'
down_revision: Union[str, Sequence[str], None] = 'aeafacf0960e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column('username', sa.String(length=30), nullable=True))
        batch_op.add_column(
            sa.Column('target_kcal_override', sa.Float(), nullable=True)
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('target_kcal_override')
        batch_op.drop_column('username')
